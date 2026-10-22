module Api
  module V1
    module Mobile
      class DeliveryController < ApplicationController
        before_action :authenticate_delivery_person!

        # GET /api/v1/mobile/delivery/tasks/today
        def tasks_today
          begin
            tasks = get_todays_tasks

            render json: {
              success: true,
              data: {
                summary: task_summary(tasks),
                tasks: format_tasks(tasks),
                route_optimization: route_optimization(tasks)
              }
            }
          rescue => e
            render json: { success: false, message: e.message }, status: :internal_server_error
          end
        end

        # GET /api/v1/mobile/delivery/tasks/:id
        def task_details
          begin
            task = find_task(params[:id])

            if task
              render json: {
                success: true,
                data: { task: format_task_details(task) }
              }
            else
              render json: { success: false, message: "Task not found" }, status: :not_found
            end
          rescue => e
            render json: { success: false, message: e.message }, status: :internal_server_error
          end
        end

        # POST /api/v1/mobile/delivery/tasks/:id/start
        def start_task
          begin
            task = find_task(params[:id])

            if task.nil?
              render json: { success: false, message: "Task not found" }, status: :not_found
              return
            end

            # Update task status to in_progress
            if update_task_status(task, 'in_progress')
              render json: {
                success: true,
                message: "Delivery started",
                data: {
                  task_id: task.id,
                  status: "in_progress",
                  started_at: Time.current,
                  estimated_arrival: estimate_arrival_time
                }
              }
            else
              render json: { success: false, message: "Failed to start delivery" }, status: :unprocessable_entity
            end
          rescue => e
            render json: { success: false, message: e.message }, status: :internal_server_error
          end
        end

        # POST /api/v1/mobile/delivery/tasks/:id/complete
        def complete_task
          begin
            task = find_task(params[:id])

            if task.nil?
              render json: { success: false, message: "Task not found" }, status: :not_found
              return
            end

            # Complete the delivery
            if complete_delivery(task, params)
              render json: {
                success: true,
                message: "Delivery completed successfully",
                data: {
                  task_id: task.id,
                  status: "completed",
                  completed_at: Time.current,
                  payment_status: "collected",
                  next_task_id: get_next_task_id
                }
              }
            else
              render json: { success: false, message: "Failed to complete delivery" }, status: :unprocessable_entity
            end
          rescue => e
            render json: { success: false, message: e.message }, status: :internal_server_error
          end
        end

        # POST /api/v1/mobile/delivery/tasks/:id/update_location
        def update_location
          begin
            task = find_task(params[:id])

            if task.nil?
              render json: { success: false, message: "Task not found" }, status: :not_found
              return
            end

            # Update delivery person location
            if update_delivery_location(params[:latitude], params[:longitude])
              distance = calculate_distance_to_customer(task, params[:latitude], params[:longitude])

              render json: {
                success: true,
                message: "Location updated",
                data: {
                  distance_to_customer: "#{distance} meters",
                  estimated_arrival: "#{(distance / 100).round} minutes"
                }
              }
            else
              render json: { success: false, message: "Failed to update location" }, status: :unprocessable_entity
            end
          rescue => e
            render json: { success: false, message: e.message }, status: :internal_server_error
          end
        end

        # POST /api/v1/mobile/delivery/bulk_mark_done
        def bulk_mark_done
          begin
            # Validate request parameters
            if params[:delivery_ids].blank? || !params[:delivery_ids].is_a?(Array)
              render json: { success: false, message: "No delivery IDs provided" }, status: :bad_request
              return
            end

            delivery_ids = params[:delivery_ids].map(&:to_i).uniq
            delivery_person_id = params[:delivery_person_id] || current_delivery_person_id
            completed_at = params[:completed_at] || Time.current

            # Process bulk updates
            result = process_bulk_delivery_update(delivery_ids, delivery_person_id, completed_at)

            if result[:updated_count] > 0
              render json: {
                success: true,
                message: "#{result[:updated_count]} of #{delivery_ids.count} deliveries marked as done",
                data: result
              }
            else
              render json: {
                success: false,
                message: "Failed to update deliveries",
                data: result
              }, status: :unprocessable_entity
            end
          rescue => e
            Rails.logger.error "Bulk delivery update error: #{e.message}"
            render json: {
              success: false,
              message: "Internal server error while processing bulk update",
              error: Rails.env.development? ? e.message : nil
            }, status: :internal_server_error
          end
        end

        # POST /api/v1/mobile/delivery/bulk_update
        def bulk_update
          begin
            # Validate request
            if params[:updates].blank? || !params[:updates].is_a?(Array)
              render json: { success: false, message: "No updates provided" }, status: :bad_request
              return
            end

            delivery_person_id = params[:delivery_person_id] || current_delivery_person_id

            # Process each update
            results = process_bulk_updates(params[:updates], delivery_person_id)

            render json: {
              success: true,
              message: "#{results[:successful_updates]} deliveries updated successfully",
              data: {
                total_processed: results[:total_processed],
                successful_updates: results[:successful_updates],
                failed_updates: results[:failed_updates],
                results: results[:results],
                summary: results[:summary]
              }
            }
          rescue => e
            Rails.logger.error "Bulk update error: #{e.message}"
            render json: {
              success: false,
              message: "Failed to process bulk updates",
              error: Rails.env.development? ? e.message : nil
            }, status: :internal_server_error
          end
        end

        private

        def authenticate_delivery_person!
          # Implement your authentication logic here
          # This should check for valid delivery person JWT token
          unless valid_delivery_person_token?
            render json: { success: false, message: "Unauthorized: Invalid or expired token" }, status: :unauthorized
          end
        end

        def valid_delivery_person_token?
          # Check JWT token from Authorization header
          token = request.headers['Authorization']&.split(' ')&.last
          return false unless token

          # Decode and verify JWT token
          begin
            decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
            @current_delivery_person = DeliveryPerson.find_by(id: decoded_token[0]['delivery_person_id'])
            @current_delivery_person.present?
          rescue JWT::DecodeError, JWT::ExpiredSignature
            false
          end
        end

        def current_delivery_person_id
          @current_delivery_person&.id
        end

        def get_todays_tasks
          # Get all bookings/orders assigned to current delivery person for today
          begin
            if defined?(Booking) && Booking.column_names.include?('delivery_person_id')
              bookings = Booking.where(delivery_person_id: current_delivery_person_id)
                              .where('DATE(created_at) = ?', Date.current)
                              .where.not(status: ['delivered', 'cancelled'])
            else
              bookings = []
            end
          rescue => e
            Rails.logger.error "Error fetching bookings: #{e.message}"
            bookings = []
          end

          # Also get subscription deliveries for today (including completed ones)
          begin
            if defined?(MilkDeliveryTask) && MilkDeliveryTask.column_names.include?('delivery_person_id')
              subscription_tasks = MilkDeliveryTask.where(
                delivery_person_id: current_delivery_person_id,
                delivery_date: Date.current
              )
            else
              subscription_tasks = []
            end
          rescue => e
            Rails.logger.error "Error fetching subscription tasks: #{e.message}"
            subscription_tasks = []
          end

          # Combine both types of tasks
          { bookings: bookings, subscriptions: subscription_tasks }
        end

        def task_summary(tasks)
          bookings = Array(tasks[:bookings])
          subscriptions = Array(tasks[:subscriptions])

          total = bookings.size + subscriptions.size
          completed = bookings.count { |b| b.status == 'delivered' } + subscriptions.count { |s| s.status == 'completed' }
          pending = total - completed

          total_collection = calculate_total_collection(bookings)

          {
            total_tasks: total,
            completed: completed,
            pending: pending,
            failed: 0,
            total_collection: total_collection
          }
        end

        def calculate_total_collection(bookings)
          return 0 if bookings.empty?
          bookings.select { |b| b.payment_method == 'cash' }.sum(&:total_amount) || 0
        rescue => e
          Rails.logger.error "Error calculating total collection: #{e.message}"
          0
        end

        def format_tasks(tasks)
          formatted_tasks = []

          # Format booking tasks
          Array(tasks[:bookings]).each do |booking|
            formatted_tasks << format_booking_task(booking)
          end

          # Format subscription tasks
          Array(tasks[:subscriptions]).each do |subscription|
            formatted_tasks << format_subscription_task(subscription)
          end

          formatted_tasks
        end

        def format_booking_task(booking)
          {
            id: booking.id,
            type: "order",
            order_number: booking.booking_number,
            customer: {
              name: booking.customer_name,
              mobile: booking.customer_phone,
              address: booking.delivery_address,
              landmark: booking.respond_to?(:landmark) ? booking.landmark : nil,
              pincode: booking.respond_to?(:pincode) ? booking.pincode : nil,
              latitude: booking.respond_to?(:latitude) ? booking.latitude : nil,
              longitude: booking.respond_to?(:longitude) ? booking.longitude : nil
            },
            items: booking.respond_to?(:booking_items) && booking.booking_items ? booking.booking_items.map { |item|
              {
                product_name: item.product&.name,
                quantity: item.quantity,
                unit: item.product&.unit_type || item.product&.unit || 'piece'
              }
            } : [],
            payment: {
              method: booking.payment_method,
              amount_to_collect: booking.payment_method == 'cash' ? booking.total_amount : 0,
              status: booking.payment_status
            },
            delivery_slot: booking.respond_to?(:delivery_slot) ? (booking.delivery_slot || "10:00 AM - 12:00 PM") : "10:00 AM - 12:00 PM",
            priority: "normal",
            status: map_booking_status(booking.status),
            special_instructions: booking.notes
          }
        end

        def format_subscription_task(subscription)
          {
            id: subscription.id,
            type: "subscription",
            order_number: "SUB-#{subscription.id}",
            customer: {
              name: subscription.customer&.display_name,
              mobile: subscription.customer&.mobile,
              address: subscription.customer&.address,
              pincode: subscription.customer&.respond_to?(:pincode) ? subscription.customer&.pincode : nil,
              latitude: subscription.customer&.latitude,
              longitude: subscription.customer&.longitude
            },
            items: [
              {
                product_name: subscription.product&.name,
                quantity: subscription.quantity,
                unit: subscription.unit
              }
            ],
            payment: {
              method: "prepaid",
              amount_to_collect: 0,
              status: "paid"
            },
            delivery_slot: subscription.respond_to?(:delivery_time) ? subscription.delivery_time : "07:00 AM - 09:00 AM",
            priority: "normal",
            status: subscription.status,
            special_instructions: nil
          }
        end

        def map_booking_status(status)
          case status
          when 'ordered_and_delivery_pending' then 'pending'
          when 'packed', 'shipped' then 'in_progress'
          when 'delivered' then 'completed'
          else status
          end
        end

        def route_optimization(tasks)
          total_tasks = tasks[:bookings].count + tasks[:subscriptions].count

          {
            suggested_sequence: suggest_route_sequence(tasks),
            estimated_completion_time: "#{(total_tasks * 15)} minutes",
            total_distance: "#{(total_tasks * 2)} km"
          }
        end

        def suggest_route_sequence(tasks)
          # Simple implementation - return task IDs
          # In production, implement actual route optimization algorithm
          task_ids = []
          task_ids += tasks[:bookings].pluck(:id)
          task_ids += tasks[:subscriptions].pluck(:id)
          task_ids.first(3)
        end

        def find_task(task_id)
          # First try to find in bookings
          booking = Booking.find_by(id: task_id)
          return booking if booking

          # Then try subscription tasks
          MilkDeliveryTask.find_by(id: task_id)
        end

        def format_task_details(task)
          if task.is_a?(Booking)
            format_booking_task(task)
          else
            format_subscription_task(task)
          end
        end

        def update_task_status(task, status)
          if task.is_a?(Booking)
            task.update(status: 'out_for_delivery')
          else
            task.update(status: 'assigned')
          end
        end

        def complete_delivery(task, params)
          ActiveRecord::Base.transaction do
            if task.is_a?(Booking)
              # Update booking status
              task.update!(
                status: 'delivered',
                delivered_at: Time.current,
                delivery_notes: params.dig(:notes),
                payment_status: params.dig(:payment_collected, :amount) ? 'paid' : task.payment_status
              )

              # Record payment if COD
              if params.dig(:payment_collected, :amount)
                record_payment(task, params[:payment_collected])
              end
            else
              # Update subscription task
              task.update!(
                status: 'completed',
                completed_at: Time.current
              )
            end

            true
          end
        rescue => e
          Rails.logger.error "Failed to complete delivery: #{e.message}"
          false
        end

        def record_payment(booking, payment_info)
          # Record payment collection
          # Implement your payment recording logic here
        end

        def get_next_task_id
          # Get next pending task for the delivery person
          next_task = Booking.where(
            delivery_person_id: current_delivery_person_id,
            status: ['ordered_and_delivery_pending', 'confirmed']
          ).where('DATE(created_at) = ?', Date.current).first

          next_task&.id || MilkDeliveryTask.where(
            delivery_person_id: current_delivery_person_id,
            delivery_date: Date.current,
            status: 'pending'
          ).first&.id
        end

        def update_delivery_location(latitude, longitude)
          # Update delivery person's current location
          # This could be stored in Redis or a location tracking table
          true
        end

        def calculate_distance_to_customer(task, lat, lng)
          # Simple distance calculation
          # In production, use proper distance calculation algorithm
          if task.respond_to?(:latitude) && task.respond_to?(:longitude)
            # Simplified distance calculation
            500 # Return 500 meters as example
          else
            1000 # Default 1km if no coordinates
          end
        end

        def estimate_arrival_time
          # Estimate arrival time based on current location and traffic
          (Time.current + 15.minutes).strftime("%I:%M %p")
        end

        def process_bulk_delivery_update(delivery_ids, delivery_person_id, completed_at)
          updated_ids = []
          failed_ids = []
          errors = []

          delivery_ids.each do |id|
            begin
              # Try to find and update booking
              booking = Booking.find_by(id: id)

              if booking.nil?
                # Try subscription task
                task = MilkDeliveryTask.find_by(id: id)

                if task.nil?
                  failed_ids << id
                  errors << { id: id, error: "Delivery not found" }
                elsif task.status == 'completed'
                  failed_ids << id
                  errors << { id: id, error: "Already completed" }
                else
                  task.update!(
                    status: 'completed',
                    completed_at: completed_at,
                    delivery_person_id: delivery_person_id
                  )
                  updated_ids << id
                end
              elsif booking.status == 'delivered'
                failed_ids << id
                errors << { id: id, error: "Already completed" }
              else
                booking.update!(
                  status: 'delivered',
                  delivered_at: completed_at,
                  delivery_person_id: delivery_person_id
                )
                updated_ids << id
              end
            rescue => e
              failed_ids << id
              errors << { id: id, error: e.message }
            end
          end

          {
            updated_count: updated_ids.count,
            updated_delivery_ids: updated_ids,
            failed_ids: failed_ids.presence,
            errors: errors.presence
          }.compact
        end

        def process_bulk_updates(updates, delivery_person_id)
          results = []
          successful = 0
          failed = 0
          delivered_count = 0
          failed_delivery_count = 0

          updates.each do |update|
            booking_id = update[:booking_id]
            booking = Booking.find_by(id: booking_id)

            if booking.nil?
              results << {
                booking_id: booking_id,
                status: "error",
                message: "Booking not found"
              }
              failed += 1
            elsif update[:status] == 'delivered'
              if booking.update(
                status: 'delivered',
                delivered_at: update[:delivered_at] || Time.current,
                delivery_notes: update[:delivery_notes],
                delivery_person_id: delivery_person_id,
                latitude: update[:latitude],
                longitude: update[:longitude]
              )
                results << {
                  booking_id: booking_id,
                  status: "success",
                  message: "Delivery marked as completed",
                  booking_number: booking.booking_number
                }
                successful += 1
                delivered_count += 1
              else
                results << {
                  booking_id: booking_id,
                  status: "error",
                  message: booking.errors.full_messages.join(", ")
                }
                failed += 1
              end
            elsif update[:status] == 'failed'
              if booking.update(
                status: 'failed_delivery',
                failed_at: update[:attempted_at] || Time.current,
                failure_reason: update[:failure_reason],
                delivery_person_id: delivery_person_id
              )
                results << {
                  booking_id: booking_id,
                  status: "success",
                  message: "Delivery marked as failed",
                  booking_number: booking.booking_number
                }
                successful += 1
                failed_delivery_count += 1
              else
                results << {
                  booking_id: booking_id,
                  status: "error",
                  message: booking.errors.full_messages.join(", ")
                }
                failed += 1
              end
            else
              results << {
                booking_id: booking_id,
                status: "error",
                message: "Invalid status"
              }
              failed += 1
            end
          end

          {
            total_processed: updates.count,
            successful_updates: successful,
            failed_updates: failed,
            results: results,
            summary: {
              delivered_count: delivered_count,
              failed_count: failed_delivery_count,
              pending_count: 0
            }
          }
        end
      end
    end
  end
end