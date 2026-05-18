// ===== IMPROVED JAVASCRIPT FOR MARALI SANTHE =====

// Cart Management
let cart = JSON.parse(localStorage.getItem('cart')) || [];
let cartTotal = 0;

// DOM Elements
const cartIcon = document.getElementById('cart-icon');
const cartModal = document.getElementById('cart-modal');
const closeCartBtn = document.getElementById('close-cart');
const cartCount = document.getElementById('cart-count');
const cartItems = document.getElementById('cart-items');
const cartTotalElement = document.getElementById('cart-total');
const cartSubtotalElement = document.getElementById('cart-subtotal');
const checkoutBtn = document.getElementById('checkout-btn');
const header = document.getElementById('header');

// Navigation
const navToggle = document.getElementById('nav-toggle');
const navMenu = document.getElementById('nav-menu');
const navLinks = document.querySelectorAll('.nav__link');

// Testimonials
const testimonialSlider = document.getElementById('testimonials-slider');
const prevBtn = document.getElementById('prev-btn');
const nextBtn = document.getElementById('next-btn');
const testimonialDots = document.querySelectorAll('.testimonial__dot');

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    updateCartUI();
    initializeNavigation();
    initializeTestimonials();
    initializeScrollEffects();
    initializeAnimations();
    initializeInteractions();
});

// ===== CART FUNCTIONS =====
function addToCart(id, name, price, image) {
    const existingItem = cart.find(item => item.id === id);

    if (existingItem) {
        existingItem.quantity += 1;
    } else {
        cart.push({
            id: id,
            name: name,
            price: price,
            image: image,
            quantity: 1
        });
    }

    localStorage.setItem('cart', JSON.stringify(cart));
    updateCartUI();
    showCartNotification(`${name} added to cart!`);

    // Add visual feedback to button
    const button = document.querySelector(`button[onclick="addToCart(${id}, '${name}', ${price}, '${image}')"]`);
    if (button) {
        button.style.transform = 'scale(0.95)';
        setTimeout(() => {
            button.style.transform = '';
        }, 150);
    }
}

function removeFromCart(id) {
    cart = cart.filter(item => item.id !== id);
    localStorage.setItem('cart', JSON.stringify(cart));
    updateCartUI();
    showCartNotification('Item removed from cart', 'info');
}

function updateQuantity(id, newQuantity) {
    if (newQuantity <= 0) {
        removeFromCart(id);
        return;
    }

    const item = cart.find(item => item.id === id);
    if (item) {
        item.quantity = newQuantity;
        localStorage.setItem('cart', JSON.stringify(cart));
        updateCartUI();
    }
}

function updateCartUI() {
    // Update cart count
    const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);
    cartCount.textContent = totalItems;

    // Animate cart count
    if (totalItems > 0) {
        cartCount.style.transform = 'scale(1.2)';
        setTimeout(() => {
            cartCount.style.transform = 'scale(1)';
        }, 200);
    }

    // Update cart items display
    if (cart.length === 0) {
        cartItems.innerHTML = `
            <div class="cart-empty">
                <div class="cart-empty__icon">
                    <i class="fas fa-shopping-cart"></i>
                </div>
                <h3 class="cart-empty__title">Your cart is empty</h3>
                <p class="cart-empty__message">Add some fresh products to get started!</p>
                <a href="#categories" class="btn btn--primary cart-empty__btn">
                    <i class="fas fa-shopping-bag"></i>
                    Start Shopping
                </a>
            </div>
        `;
    } else {
        cartItems.innerHTML = cart.map(item => `
            <div class="cart-item" data-item-id="${item.id}">
                <img src="${item.image}" alt="${item.name}" class="cart-item__image">
                <div class="cart-item__details">
                    <div class="cart-item__name">${item.name}</div>
                    <div class="cart-item__price">₹${item.price}</div>
                </div>
                <div class="cart-item__quantity">
                    <button class="quantity-btn" onclick="updateQuantity(${item.id}, ${item.quantity - 1})">
                        <i class="fas fa-minus"></i>
                    </button>
                    <span class="quantity-display">${item.quantity}</span>
                    <button class="quantity-btn" onclick="updateQuantity(${item.id}, ${item.quantity + 1})">
                        <i class="fas fa-plus"></i>
                    </button>
                    <button class="quantity-btn remove-btn" onclick="removeFromCart(${item.id})" title="Remove item">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </div>
        `).join('');
    }

    // Update totals
    cartTotal = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    if (cartTotalElement) cartTotalElement.textContent = cartTotal;
    if (cartSubtotalElement) cartSubtotalElement.textContent = cartTotal;
}

function showCartNotification(message, type = 'success') {
    // Remove existing notifications
    const existingNotifications = document.querySelectorAll('.cart-notification');
    existingNotifications.forEach(notif => notif.remove());

    // Create notification element
    const notification = document.createElement('div');
    notification.className = `cart-notification cart-notification--${type}`;
    notification.style.cssText = `
        position: fixed;
        top: 100px;
        right: 20px;
        background: ${type === 'success' ? '#22C55E' : '#3B82F6'};
        color: white;
        padding: 1rem 1.5rem;
        border-radius: 12px;
        z-index: 3000;
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
        transform: translateX(100%);
        opacity: 0;
        transition: all 0.3s ease;
        max-width: 300px;
    `;

    notification.innerHTML = `
        <div style="display: flex; align-items: center; gap: 0.75rem;">
            <i class="fas ${type === 'success' ? 'fa-check-circle' : 'fa-info-circle'}"></i>
            <span>${message}</span>
            <button onclick="this.parentElement.parentElement.remove()" style="background: none; border: none; color: white; margin-left: auto; cursor: pointer; opacity: 0.8;">
                <i class="fas fa-times"></i>
            </button>
        </div>
    `;

    // Add to page
    document.body.appendChild(notification);

    // Animate in
    setTimeout(() => {
        notification.style.transform = 'translateX(0)';
        notification.style.opacity = '1';
    }, 100);

    // Remove after 4 seconds
    setTimeout(() => {
        notification.style.transform = 'translateX(100%)';
        notification.style.opacity = '0';
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, 300);
    }, 4000);
}

// ===== NAVIGATION FUNCTIONS =====
function initializeNavigation() {
    // Mobile menu toggle
    if (navToggle && navMenu) {
        navToggle.addEventListener('click', () => {
            navMenu.classList.toggle('active');
            navToggle.classList.toggle('active');
        });
    }

    // Close mobile menu when clicking outside
    document.addEventListener('click', (e) => {
        if (!navToggle.contains(e.target) && !navMenu.contains(e.target)) {
            navMenu.classList.remove('active');
            navToggle.classList.remove('active');
        }
    });

    // Close mobile menu when clicking links
    navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            // Update active link
            navLinks.forEach(l => l.classList.remove('active'));
            link.classList.add('active');

            // Close mobile menu
            if (navMenu.classList.contains('active')) {
                navMenu.classList.remove('active');
                navToggle.classList.remove('active');
            }
        });
    });

    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                const headerHeight = header.offsetHeight;
                const targetPosition = target.offsetTop - headerHeight - 20;

                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
}

// ===== CART MODAL FUNCTIONS =====
if (cartIcon) {
    cartIcon.addEventListener('click', () => {
        cartModal.style.display = 'flex';
        document.body.style.overflow = 'hidden';

        // Animate modal
        setTimeout(() => {
            cartModal.querySelector('.cart-modal__content').style.transform = 'scale(1)';
            cartModal.querySelector('.cart-modal__content').style.opacity = '1';
        }, 10);
    });
}

if (closeCartBtn) {
    closeCartBtn.addEventListener('click', closeCartModal);
}

// Close cart modal when clicking overlay
if (cartModal) {
    cartModal.addEventListener('click', (e) => {
        if (e.target === cartModal || e.target.classList.contains('cart-modal__overlay')) {
            closeCartModal();
        }
    });
}

function closeCartModal() {
    const content = cartModal.querySelector('.cart-modal__content');
    content.style.transform = 'scale(0.95)';
    content.style.opacity = '0';

    setTimeout(() => {
        cartModal.style.display = 'none';
        document.body.style.overflow = 'auto';
        content.style.transform = 'scale(1)';
        content.style.opacity = '1';
    }, 300);
}

// Checkout function
if (checkoutBtn) {
    checkoutBtn.addEventListener('click', () => {
        if (cart.length === 0) {
            showCartNotification('Your cart is empty!', 'info');
            return;
        }

        // Add loading state
        checkoutBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Processing...';
        checkoutBtn.disabled = true;

        setTimeout(() => {
            const total = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
            const orderDetails = cart.map(item => `${item.name} x${item.quantity}`).join(', ');

            if (confirm(`Proceed with order?\n\nItems: ${orderDetails}\nTotal: ₹${total}\n\nThis will redirect you to the checkout page.`)) {
                showCartNotification('Order placed successfully! 🎉', 'success');

                // Clear cart after successful checkout
                cart = [];
                localStorage.setItem('cart', JSON.stringify(cart));
                updateCartUI();
                closeCartModal();
            }

            // Reset button
            checkoutBtn.innerHTML = '<i class="fas fa-lock"></i> Proceed to Checkout';
            checkoutBtn.disabled = false;
        }, 2000);
    });
}

// ===== TESTIMONIALS SLIDER =====
function initializeTestimonials() {
    let currentSlide = 0;
    const slides = document.querySelectorAll('.testimonial__card');
    const totalSlides = slides.length;

    if (totalSlides === 0) return;

    function showSlide(index) {
        slides.forEach((slide, i) => {
            slide.style.transform = `translateX(${(i - index) * 100}%)`;
            slide.style.opacity = i === index ? '1' : '0';
        });

        // Update dots
        testimonialDots.forEach((dot, i) => {
            dot.classList.toggle('testimonial__dot--active', i === index);
        });
    }

    function nextSlide() {
        currentSlide = (currentSlide + 1) % totalSlides;
        showSlide(currentSlide);
    }

    function prevSlide() {
        currentSlide = (currentSlide - 1 + totalSlides) % totalSlides;
        showSlide(currentSlide);
    }

    // Initialize first slide
    showSlide(0);

    // Event listeners
    if (nextBtn) {
        nextBtn.addEventListener('click', nextSlide);
    }

    if (prevBtn) {
        prevBtn.addEventListener('click', prevSlide);
    }

    // Dot navigation
    testimonialDots.forEach((dot, index) => {
        dot.addEventListener('click', () => {
            currentSlide = index;
            showSlide(currentSlide);
        });
    });

    // Auto-advance slides
    setInterval(nextSlide, 6000);

    // Pause on hover
    const testimonialContainer = document.querySelector('.testimonials__slider');
    if (testimonialContainer) {
        let autoSlideInterval = setInterval(nextSlide, 6000);

        testimonialContainer.addEventListener('mouseenter', () => {
            clearInterval(autoSlideInterval);
        });

        testimonialContainer.addEventListener('mouseleave', () => {
            autoSlideInterval = setInterval(nextSlide, 6000);
        });
    }
}

// ===== SCROLL EFFECTS =====
function initializeScrollEffects() {
    let lastScrollY = window.scrollY;

    window.addEventListener('scroll', () => {
        const currentScrollY = window.scrollY;

        // Header scroll effect
        if (currentScrollY > 100) {
            header.style.background = 'rgba(255, 255, 255, 0.95)';
            header.style.backdropFilter = 'blur(10px)';
            header.style.borderBottom = '1px solid #E5E7EB';
        } else {
            header.style.background = 'rgba(255, 255, 255, 0.95)';
            header.style.backdropFilter = 'blur(10px)';
            header.style.borderBottom = '1px solid #F3F4F6';
        }

        // Hide/show header based on scroll direction
        if (currentScrollY > lastScrollY && currentScrollY > 200) {
            header.style.transform = 'translateY(-100%)';
        } else {
            header.style.transform = 'translateY(0)';
        }

        lastScrollY = currentScrollY;
    });

    // Intersection Observer for animations
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.animationPlayState = 'running';
                entry.target.classList.add('animate-in');
            }
        });
    }, observerOptions);

    // Observe elements for animation
    const animatedElements = document.querySelectorAll('.category__card, .product__card, .feature__card, .hero__content');
    animatedElements.forEach((el, index) => {
        el.style.animationDelay = `${index * 100}ms`;
        el.style.animationFillMode = 'both';
        observer.observe(el);
    });
}

// ===== ANIMATIONS =====
function initializeAnimations() {
    // Add custom animations
    const style = document.createElement('style');
    style.textContent = `
        @keyframes slideInUp {
            from {
                opacity: 0;
                transform: translateY(50px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        @keyframes slideInLeft {
            from {
                opacity: 0;
                transform: translateX(-50px);
            }
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }

        @keyframes slideInRight {
            from {
                opacity: 0;
                transform: translateX(50px);
            }
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }

        .animate-in {
            animation: slideInUp 0.6s ease forwards;
        }

        .hero__text {
            animation: slideInLeft 0.8s ease forwards;
        }

        .hero__visual {
            animation: slideInRight 0.8s ease forwards;
        }
    `;
    document.head.appendChild(style);
}

// ===== INTERACTIVE FEATURES =====
function initializeInteractions() {
    // Search functionality
    const searchInput = document.querySelector('.search__input');
    const searchBtn = document.querySelector('.search__btn');

    if (searchInput) {
        searchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                performSearch(this.value.trim());
            }
        });

        // Search suggestions (placeholder)
        searchInput.addEventListener('input', function() {
            const value = this.value.trim();
            if (value.length > 2) {
                // In a real app, this would show search suggestions
                console.log('Search suggestions for:', value);
            }
        });
    }

    if (searchBtn) {
        searchBtn.addEventListener('click', function() {
            const searchValue = searchInput ? searchInput.value.trim() : '';
            performSearch(searchValue);
        });
    }

    // Newsletter subscription
    const newsletterBtn = document.querySelector('.newsletter__btn');
    const newsletterInput = document.querySelector('.newsletter__input');

    if (newsletterBtn && newsletterInput) {
        newsletterBtn.addEventListener('click', () => {
            const email = newsletterInput.value.trim();

            if (!email) {
                showCartNotification('Please enter your email address', 'info');
                return;
            }

            if (!isValidEmail(email)) {
                showCartNotification('Please enter a valid email address', 'info');
                return;
            }

            // Add loading state
            const originalText = newsletterBtn.innerHTML;
            newsletterBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Subscribing...';
            newsletterBtn.disabled = true;

            setTimeout(() => {
                showCartNotification('Thank you for subscribing! 📧', 'success');
                newsletterInput.value = '';
                newsletterBtn.innerHTML = originalText;
                newsletterBtn.disabled = false;
            }, 1500);
        });

        newsletterInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                newsletterBtn.click();
            }
        });
    }

    // Category interactions
    document.querySelectorAll('.category__btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const categoryName = this.closest('.category__card').querySelector('.category__title').textContent;
            showCartNotification(`Browsing ${categoryName}...`, 'info');

            // In a real app, this would filter products or redirect
            setTimeout(() => {
                document.querySelector('#shop').scrollIntoView({ behavior: 'smooth' });
            }, 1000);
        });
    });

    // Product interactions
    document.querySelectorAll('.product__wishlist').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            const icon = this.querySelector('i');

            if (icon.classList.contains('far')) {
                icon.classList.remove('far');
                icon.classList.add('fas');
                this.style.background = '#EF4444';
                this.style.color = 'white';
                showCartNotification('Added to wishlist! ❤️', 'success');
            } else {
                icon.classList.remove('fas');
                icon.classList.add('far');
                this.style.background = '';
                this.style.color = '';
                showCartNotification('Removed from wishlist', 'info');
            }
        });
    });

    // Quick view functionality
    document.querySelectorAll('.product__quick-view').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            const productCard = this.closest('.product__card');
            const productName = productCard.querySelector('.product__title').textContent;
            showCartNotification(`Quick view: ${productName}`, 'info');

            // In a real app, this would open a product modal
        });
    });

    // Copy coupon code functionality
    window.copyCode = function(code) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(code).then(() => {
                showCartNotification(`Coupon code "${code}" copied! 📋`, 'success');
            });
        } else {
            // Fallback for older browsers
            const textArea = document.createElement('textarea');
            textArea.value = code;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            showCartNotification(`Coupon code "${code}" copied! 📋`, 'success');
        }
    };

    // Parallax effect for hero section
    window.addEventListener('scroll', () => {
        const scrolled = window.pageYOffset;
        const heroImg = document.querySelector('.hero__img');
        if (heroImg) {
            heroImg.style.transform = `translateY(${scrolled * 0.5}px)`;
        }
    });
}

// ===== UTILITY FUNCTIONS =====
function performSearch(searchTerm) {
    if (!searchTerm) {
        showCartNotification('Please enter a search term', 'info');
        return;
    }

    showCartNotification(`Searching for "${searchTerm}"...`, 'info');

    // In a real application, this would perform actual search
    setTimeout(() => {
        document.querySelector('#shop').scrollIntoView({ behavior: 'smooth' });
    }, 1000);
}

function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

// ===== KEYBOARD ACCESSIBILITY =====
document.addEventListener('keydown', function(e) {
    // Close modals with Escape key
    if (e.key === 'Escape') {
        if (cartModal && cartModal.style.display === 'flex') {
            closeCartModal();
        }
        if (navMenu && navMenu.classList.contains('active')) {
            navMenu.classList.remove('active');
            navToggle.classList.remove('active');
        }
    }

    // Open cart with Ctrl+Shift+C
    if (e.ctrlKey && e.shiftKey && e.key === 'C') {
        e.preventDefault();
        if (cartIcon) cartIcon.click();
    }
});

// ===== PERFORMANCE OPTIMIZATION =====
// Debounce function for scroll events
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Throttle function for resize events
function throttle(func, limit) {
    let inThrottle;
    return function() {
        const args = arguments;
        const context = this;
        if (!inThrottle) {
            func.apply(context, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

// Handle window resize
window.addEventListener('resize', throttle(() => {
    // Close mobile menu on resize
    if (window.innerWidth > 768) {
        navMenu.classList.remove('active');
        navToggle.classList.remove('active');
    }
}, 250));

// ===== LOADING STATES =====
document.addEventListener('DOMContentLoaded', () => {
    // Add loading states to buttons
    document.querySelectorAll('.btn:not(.product__add-btn)').forEach(btn => {
        btn.addEventListener('click', function(e) {
            if (this.href && this.href.includes('#')) {
                return; // Skip for anchor links
            }

            const originalText = this.innerHTML;
            this.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Loading...';
            this.disabled = true;

            setTimeout(() => {
                this.innerHTML = originalText;
                this.disabled = false;
            }, 1500);
        });
    });

    console.log('🌱 Dhanvantri Naturals website loaded successfully!');
});