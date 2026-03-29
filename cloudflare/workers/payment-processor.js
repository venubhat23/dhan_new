// Cloudflare Worker for Payment Processing
// This worker will handle payment creation and webhook processing

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  const pathname = url.pathname

  // CORS headers for all responses
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
  }

  // Handle CORS preflight requests
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders
    })
  }

  try {
    // Route handling
    if (pathname === '/payment/create-order' && request.method === 'POST') {
      return await handleCreateOrder(request, corsHeaders)
    }

    if (pathname === '/payment/webhook' && request.method === 'POST') {
      return await handleWebhook(request, corsHeaders)
    }

    if (pathname === '/payment/verify' && request.method === 'POST') {
      return await handleVerifyPayment(request, corsHeaders)
    }

    return new Response('Not Found', {
      status: 404,
      headers: corsHeaders
    })
  } catch (error) {
    console.error('Worker Error:', error)
    return new Response(JSON.stringify({
      success: false,
      message: 'Internal server error',
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  }
}

async function handleCreateOrder(request, corsHeaders) {
  const data = await request.json()

  // Validate request data
  if (!data.cart_items || data.cart_items.length === 0) {
    return new Response(JSON.stringify({
      success: false,
      message: 'Cart is empty'
    }), {
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  }

  // Calculate total amount
  let totalAmount = 0
  data.cart_items.forEach(item => {
    totalAmount += (item.price * item.quantity)
  })

  // Generate unique order ID
  const orderId = `CF_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`

  // Create payment session (simulate payment gateway integration)
  const paymentSessionId = `session_${orderId}_${Math.random().toString(36).substr(2, 9)}`

  // Store order in Cloudflare KV (you'll need to bind a KV namespace)
  const orderData = {
    order_id: orderId,
    payment_session_id: paymentSessionId,
    amount: totalAmount,
    currency: 'INR',
    customer_email: data.customer_email,
    customer_name: data.customer_name,
    customer_phone: data.customer_phone,
    delivery_address: data.delivery_address,
    cart_items: data.cart_items,
    delivery_method: data.delivery_method,
    pickup_location: data.pickup_location,
    payment_method: data.payment_method,
    status: 'created',
    created_at: new Date().toISOString(),
    webhook_url: data.webhook_url || `${new URL(request.url).origin}/payment/webhook`
  }

  // Store in KV (assuming you have PAYMENT_ORDERS KV namespace bound)
  try {
    await PAYMENT_ORDERS.put(orderId, JSON.stringify(orderData), {
      expirationTtl: 3600 // 1 hour expiry
    })
  } catch (error) {
    console.error('KV Storage Error:', error)
    // Continue without KV storage for now
  }

  // Return payment session details
  return new Response(JSON.stringify({
    success: true,
    order_id: orderId,
    payment_session_id: paymentSessionId,
    amount: totalAmount,
    currency: 'INR',
    payment_url: `${new URL(request.url).origin}/payment/process?session_id=${paymentSessionId}`,
    webhook_url: orderData.webhook_url
  }), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders
    }
  })
}

async function handleWebhook(request, corsHeaders) {
  const webhookData = await request.json()

  console.log('Webhook received:', webhookData)

  // Validate webhook signature (implement your signature validation logic)
  if (!validateWebhookSignature(request, webhookData)) {
    return new Response(JSON.stringify({
      success: false,
      message: 'Invalid webhook signature'
    }), {
      status: 401,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  }

  // Process webhook based on event type
  const { event_type, order_id, payment_status, payment_details } = webhookData

  try {
    // Get order from KV storage
    const orderDataStr = await PAYMENT_ORDERS.get(order_id)
    if (!orderDataStr) {
      throw new Error('Order not found')
    }

    const orderData = JSON.parse(orderDataStr)

    // Update order status based on webhook
    if (event_type === 'payment.success') {
      orderData.status = 'paid'
      orderData.payment_status = 'SUCCESS'
      orderData.payment_details = payment_details
      orderData.paid_at = new Date().toISOString()
    } else if (event_type === 'payment.failed') {
      orderData.status = 'failed'
      orderData.payment_status = 'FAILED'
      orderData.failure_reason = payment_details?.failure_reason
      orderData.failed_at = new Date().toISOString()
    }

    // Update order in KV storage
    await PAYMENT_ORDERS.put(order_id, JSON.stringify(orderData))

    // Forward webhook to your Rails application
    const railsWebhookUrl = orderData.webhook_url || 'https://your-app.com/payment/webhook'

    try {
      const response = await fetch(railsWebhookUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Webhook-Source': 'cloudflare-worker',
          'X-Order-ID': order_id
        },
        body: JSON.stringify({
          event_type,
          order_id,
          payment_status,
          payment_details,
          order_data: orderData
        })
      })

      if (!response.ok) {
        throw new Error(`Rails webhook failed: ${response.status}`)
      }

      console.log('Successfully forwarded webhook to Rails app')
    } catch (error) {
      console.error('Failed to forward webhook to Rails:', error)
      // Don't fail the webhook response, just log the error
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Webhook processed successfully'
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  } catch (error) {
    console.error('Webhook processing error:', error)
    return new Response(JSON.stringify({
      success: false,
      message: 'Webhook processing failed',
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  }
}

async function handleVerifyPayment(request, corsHeaders) {
  const { order_id, payment_id } = await request.json()

  if (!order_id) {
    return new Response(JSON.stringify({
      success: false,
      message: 'Order ID is required'
    }), {
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  }

  try {
    // Get order from KV storage
    const orderDataStr = await PAYMENT_ORDERS.get(order_id)
    if (!orderDataStr) {
      throw new Error('Order not found')
    }

    const orderData = JSON.parse(orderDataStr)

    return new Response(JSON.stringify({
      success: true,
      order_id: orderData.order_id,
      payment_status: orderData.payment_status || 'PENDING',
      status: orderData.status,
      amount: orderData.amount,
      payment_details: orderData.payment_details || {}
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      message: 'Payment verification failed',
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  }
}

function validateWebhookSignature(request, data) {
  // Implement your webhook signature validation logic
  // For now, just return true (implement proper validation in production)
  const signature = request.headers.get('X-Webhook-Signature')

  // Example validation (replace with your actual logic)
  // const expectedSignature = crypto.subtle.digest('SHA-256', JSON.stringify(data))
  // return signature === expectedSignature

  return true // Simplified for example
}