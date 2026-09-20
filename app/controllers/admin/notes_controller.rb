class Admin::NotesController < ApplicationController
  before_action :set_note, only: [:show, :edit, :update, :destroy]

  def index
    @notes = Note.includes(:created_by_user).recent

    # Apply filters
    @notes = @notes.by_status(params[:status]) if params[:status].present?
    @notes = @notes.by_payment_method(params[:payment_method]) if params[:payment_method].present?
    @notes = @notes.by_paid_from(params[:paid_from]) if params[:paid_from].present?
    @notes = @notes.by_paid_to_category(params[:paid_to_category]) if params[:paid_to_category].present?

    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      @notes = @notes.by_date_range(Date.parse(params[:start_date]), Date.parse(params[:end_date]))
    end

    # Search filter
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @notes = @notes.where("title ILIKE ? OR paid_to ILIKE ? OR reference_number ILIKE ?",
                           search_term, search_term, search_term)
    end

    @notes = @notes.page(params[:page]).per(20)

    # Calculate statistics
    @stats = calculate_note_stats
  end

  def show
  end

  def new
    @note = Note.new
  end

  def create
    @note = Note.new(note_params)
    @note.created_by_user = current_user

    if @note.save
      redirect_to admin_notes_path, notice: 'Note created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @note.update(note_params)
      redirect_to admin_notes_path, notice: 'Note updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @note.destroy
    redirect_to admin_notes_path, notice: 'Note deleted successfully.'
  end

  private

  def set_note
    @note = Note.find(params[:id])
  end

  def note_params
    params.require(:note).permit(:title, :paid_to, :amount, :payment_method,
                                 :reference_number, :description, :status, :note_date,
                                 :paid_from, :paid_to_category)
  end

  def calculate_note_stats
    # One grouped query (count + sum per status) instead of 7 separate aggregates.
    by_status = Note.group(:status).pluck(:status, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(amount), 0)'))
                    .index_by(&:first)
    count_of  = ->(status) { by_status[status]&.[](1).to_i }
    amount_of = ->(status) { by_status[status]&.[](2) || 0 }

    {
      total_notes: by_status.values.sum { |row| row[1].to_i },
      total_amount: by_status.values.sum { |row| row[2] || 0 },
      pending_count: count_of.call('pending'),
      completed_count: count_of.call('completed'),
      cancelled_count: count_of.call('cancelled'),
      pending_amount: amount_of.call('pending'),
      completed_amount: amount_of.call('completed')
    }
  end
end