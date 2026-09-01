# One-shot stock seeder — BATCH 2 (groceries, spices, personal & home care).
#   bin/rails runner scratch_seed_stock2.rb
#
# Behaves like scratch_seed_stock.rb EXCEPT it does NOT wipe anything — it is a
# continuation of scratch_seed_stock.rb and adds on top of what that seeded.
# - Inserts central + store stock from the sheet below.
# - Central stock -> product_variant.available_stock (+ a central StockBatch per positive qty)
# - Store stock   -> StoreInventory row (+ a store StockBatch per positive qty)
# - "store low stock" -> StoreInventory#low_stock_threshold (per variant)
# Store = "Gandhi Bazar" if present, else the only store (when there is exactly one).
#
# NOTE: run scratch_seed_stock.rb FIRST (it wipes + seeds batch 1), then this.
# Tweaks vs batch 1:
#   * a product that isn't in the catalog is logged and skipped (run is not aborted)
#   * a blank category column leaves the product's category untouched
#   * a blank weight/unit means the row targets the variant-less product itself

SHEET = [
  # name,                              weight, unit,   store_low, store_qty, central, central_low, category
  # ---- SWEETNERS ----
  ["Jaggery",                            1,   "Kg",   4,   1,   6,   nil, "Sweetners"],
  ["Khandsari Sugar",                    1,   "Kg",   3,   6,   5,   nil, "Sweetners"],
  ["Brown Sugar",                        1,   "Kg",   5,   3,   30,  nil, "Sweetners"],
  ["Liquid Jaggery",                     1,   "Kg",   5,   4,   16,  nil, "Sweetners"],
  ["Powder Jaggery",                     1,   "Kg",   5,   8,   35,  nil, "Sweetners"],
  ["Honey",                              0.5, "Kg",   4,   8,   28,  nil, "Sweetners"],
  ["Honey",                              300, "Ml",   4,   nil, nil, nil, "Sweetners"],
  ["Kulfi Jaggery",                      1,   "Kg",   nil, nil, nil, nil, "Sweetners"],
  ["Kulfi Jaggery",                      0.5, "Kg",   2,   nil, nil, nil, "Sweetners"],

  # ---- RICE & WHEAT (1Kg) ----
  ["Ambemohar Rice",                     1,   "Kg",   2,   6,   nil, nil, "Rice"],
  ["Delhi Basmati Rice",                 1,   "Kg",   2,   2,   3,   nil, "Rice"],
  ["HMT Rice",                           1,   "Kg",   5,   5,   5,   nil, "Rice"],
  ["Indrayani Rice",                     1,   "Kg",   3,   8,   nil, nil, "Rice"],
  ["Jeerigesanna Rice",                  1,   "Kg",   3,   3,   22,  nil, "Rice"],
  ["Kuchalakki Rice",                    1,   "Kg",   nil, nil, 2,   nil, "Rice"],
  ["Rajamudi Rice",                      1,   "Kg",   3,   3,   3,   nil, "Rice"],
  ["Raktashali Rice",                    1,   "Kg",   4,   2,   1.5, nil, "Rice"],
  ["RNR Rice",                           1,   "Kg",   4,   4,   nil, nil, "Rice"],
  ["Sonamasoori Rice",                   1,   "Kg",   4,   3,   1,   nil, "Rice"],
  ["Jave Wheat",                         1,   "Kg",   4,   2,   nil, nil, "Wheat"],
  ["Wheat",                              1,   "Kg",   4,   5,   5,   nil, "Wheat"],
  ["Idli rice",                          nil, nil,    3,   4,   nil, nil, ""],
  ["Belguam Basmati",                    1,   "Kg",   nil, nil, nil, nil, "Rice"],

  # ---- DALS AND PULSES (1Kg) ----
  ["Alasandi Red",                       1,   "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Alasandi Red",                       0.5, "Kg",   2,   1,   1,   nil, "Dals and Pulses"],
  ["Alasandi White",                     1,   "Kg",   nil, nil, 3,   nil, "Dals and Pulses"],
  ["Alasandi White",                     0.5, "Kg",   2,   8,   nil, nil, "Dals and Pulses"],
  ["Black Peas",                         1,   "Kg",   nil, nil, 2,   nil, "Dals and Pulses"],
  ["Black Peas",                         0.5, "Kg",   2,   9,   nil, nil, "Dals and Pulses"],
  ["Chana Black",                        1,   "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Chana Black",                        0.5, "Kg",   2,   1,   nil, nil, "Dals and Pulses"],
  ["Chana Dal",                          1,   "Kg",   nil, nil, 1,   nil, "Dals and Pulses"],
  ["Chana Dal",                          0.5, "Kg",   4,   7,   nil, nil, "Dals and Pulses"],
  ["Chana Red",                          1,   "Kg",   nil, nil, 1,   nil, "Dals and Pulses"],
  ["Chana Red",                          0.5, "Kg",   4,   2,   nil, nil, "Dals and Pulses"],
  ["Desi Toor Dal",                      1,   "Kg",   2,   1,   8,   nil, "Dals and Pulses"],
  ["Desi Toor Dal",                      0.5, "Kg",   4,   3,   nil, nil, "Dals and Pulses"],
  ["Fried Gram",                         1,   "Kg",   nil, nil, 5,   nil, "Dals and Pulses"],
  ["Fried Gram",                         0.5, "Kg",   4,   2,   nil, nil, "Dals and Pulses"],
  ["Green Peas",                         1,   "Kg",   nil, nil, 3.5, nil, "Dals and Pulses"],
  ["Green Peas",                         0.5, "Kg",   4,   10,  nil, nil, "Dals and Pulses"],
  ["Groundnut",                          1,   "Kg",   2,   3,   4.5, nil, "Dals and Pulses"],
  ["Groundnut",                          0.5, "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Horse Gram",                         1,   "Kg",   nil, nil, 2.5, nil, "Dals and Pulses"],
  ["Horse Gram",                         0.5, "Kg",   2,   2,   nil, nil, "Dals and Pulses"],
  ["Kabuli Chana",                       1,   "Kg",   nil, nil, 1,   nil, "Dals and Pulses"],
  ["Kabuli Chana",                       0.5, "Kg",   4,   5,   nil, nil, "Dals and Pulses"],
  ["Masoor",                             1,   "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Masoor",                             0.5, "Kg",   2,   23,  3,   nil, "Dals and Pulses"],
  ["Masoor Dal",                         1,   "Kg",   nil, nil, 2.5, nil, "Dals and Pulses"],
  ["Masoor Dal",                         0.5, "Kg",   4,   7,   nil, nil, "Dals and Pulses"],
  ["Mataki (Moth Beans)",                1,   "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Mataki (Moth Beans)",                0.5, "Kg",   4,   13,  nil, nil, "Dals and Pulses"],
  ["Moong Black",                        1,   "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Moong Black",                        0.5, "Kg",   nil, 3,   nil, nil, "Dals and Pulses"],
  ["Moong Dal",                          1,   "Kg",   nil, nil, 3,   nil, "Dals and Pulses"],
  ["Moong Dal",                          0.5, "Kg",   4,   4,   nil, nil, "Dals and Pulses"],
  ["Moong Dal (With Husk)",              1,   "Kg",   2,   6,   nil, nil, "Dals and Pulses"],
  ["Moong Dal (With Husk)",              0.5, "Kg",   nil, 9,   nil, nil, "Dals and Pulses"],
  ["Moong",                              1,   "Kg",   2,   2,   8,   nil, "Dals and Pulses"],
  ["Moong",                              0.5, "Kg",   2,   nil, nil, nil, "Dals and Pulses"],
  ["Rajma",                              1,   "Kg",   nil, nil, 3,   nil, "Dals and Pulses"],
  ["Rajma",                              0.5, "Kg",   4,   5,   nil, nil, "Dals and Pulses"],
  ["Soya Bean",                          1,   "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Soya Bean",                          0.5, "Kg",   4,   5,   1,   nil, "Dals and Pulses"],
  ["Toor Dal",                           1,   "Kg",   2,   6,   1.5, nil, "Dals and Pulses"],
  ["Toor Dal",                           0.5, "Kg",   4,   3,   nil, nil, "Dals and Pulses"],
  ["Urad",                               1,   "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Urad",                               0.5, "Kg",   nil, nil, nil, nil, "Dals and Pulses"],
  ["Urad Dal",                           1,   "Kg",   nil, 2,   2.4, nil, "Dals and Pulses"],
  ["Urad Dal",                           0.5, "Kg",   4,   11,  nil, nil, "Dals and Pulses"],

  # ---- SEEDS AND SPICES ----
  ["Flax Seeds",                         1,   "Kg",   nil, nil, 5.5,  nil, "Seeds and Spices"],
  ["Jeera",                              1,   "Kg",   nil, nil, 3,    nil, "Seeds and Spices"],
  ["Methi Seeds",                        1,   "Kg",   nil, nil, 2,    nil, "Seeds and Spices"],
  ["Niger seeds",                        1,   "Kg",   nil, nil, nil,  nil, "Seeds and Spices"],
  ["Mustard Seeds",                      1,   "Kg",   nil, nil, 8,    nil, "Seeds and Spices"],
  ["Sesame Seeds (Black)",               1,   "Kg",   nil, nil, 3.2,  nil, "Seeds and Spices"],
  ["Sesame Seeds (White)",               1,   "Kg",   nil, nil, 1.75, nil, "Seeds and Spices"],
  ["Byadagi Chilli",                     1,   "Kg",   nil, nil, nil,  nil, "Seeds and Spices"],
  ["Guntur Chilli",                      1,   "Kg",   nil, nil, 1,    nil, "Seeds and Spices"],
  ["Byadagi Chilli Powder",              1,   "Kg",   nil, nil, 2.65, nil, "Seeds and Spices"],
  ["Dhaniya",                            1,   "Kg",   nil, nil, 1.5,  nil, "Seeds and Spices"],
  ["Guntur Chilli Powder",               1,   "Kg",   nil, nil, 4,    nil, "Seeds and Spices"],
  ["Ajwain",                             100, "Gram", 6,   5,   7,    nil, "Seeds and Spices"],
  ["Ajwain",                             250, "Gram", 6,   5,   nil,  nil, "Seeds and Spices"],
  ["Dhaniya",                            100, "Gram", 6,   1,   nil,  nil, "Seeds and Spices"],
  ["Dhaniya",                            500, "Gram", 6,   1,   nil,  nil, "Seeds and Spices"],
  ["Flax Seeds",                         100, "Gram", 6,   10,  nil,  nil, "Seeds and Spices"],
  ["Jeera",                              100, "Gram", 6,   12,  nil,  nil, "Seeds and Spices"],
  ["Methi Seeds",                        100, "Gram", 6,   30,  nil,  nil, "Seeds and Spices"],
  ["Niger seeds",                        100, "Gram", 6,   nil, nil,  nil, "Seeds and Spices"],
  ["Mustard Seeds",                      100, "Gram", 6,   12,  nil,  nil, "Seeds and Spices"],
  ["Sesame Seeds (Black)",               100, "Gram", 6,   15,  nil,  nil, "Seeds and Spices"],
  ["Sesame Seeds (White)",               100, "Gram", 6,   15,  nil,  nil, "Seeds and Spices"],
  ["Byadagi Chilli",                     100, "Gram", 6,   14,  nil,  nil, "Seeds and Spices"],
  ["Guntur Chilli",                      100, "Gram", 6,   16,  nil,  nil, "Seeds and Spices"],
  ["Byadagi Chilli Powder",              100, "Gram", 6,   15,  nil,  nil, "Seeds and Spices"],
  ["Guntur Chilli Powder",               100, "Gram", 6,   nil, nil,  nil, "Seeds and Spices"],
  ["Flax Seeds",                         250, "Gram", 4,   2,   nil,  nil, "Seeds and Spices"],
  ["Jeera",                              250, "Gram", 4,   2,   nil,  nil, "Seeds and Spices"],
  ["Methi Seeds",                        250, "Gram", 4,   3,   nil,  nil, "Seeds and Spices"],
  ["Niger seeds",                        250, "Gram", 4,   nil, nil,  nil, "Seeds and Spices"],
  ["Mustard Seeds",                      250, "Gram", 4,   nil, nil,  nil, "Seeds and Spices"],
  ["Sesame Seeds (Black)",               250, "Gram", 4,   nil, nil,  nil, "Seeds and Spices"],
  ["Sesame Seeds (White)",               250, "Gram", 4,   nil, nil,  nil, "Seeds and Spices"],
  ["Byadagi Chilli",                     250, "Gram", 4,   2,   nil,  nil, "Seeds and Spices"],
  ["Guntur Chilli",                      250, "Gram", 4,   4,   nil,  nil, "Seeds and Spices"],
  ["Byadagi Chilli Powder",              250, "Gram", 4,   5,   nil,  nil, "Seeds and Spices"],
  ["Dhaniya",                            250, "Gram", 4,   nil, nil,  nil, "Seeds and Spices"],
  ["Guntur Chilli Powder",               250, "Gram", 4,   6,   nil,  nil, "Seeds and Spices"],

  # ---- KITCHEN ESSENTIALS ----
  ["Himalayan Rock Salt (Crystal)",      500, "Gram", 5,   25,  31,   nil, "Seeds and Spices"],
  ["Himalayan Rock Salt (Powder)",       500, "Gram", 5,   13,  15.5, nil, "Seeds and Spices"],
  ["Moringa Powder",                     200, "Gram", 2,   8,   nil,  nil, "Seeds and Spices"],
  ["Tamarind",                           1,   "Kg",   nil, nil, 26,   nil, "Seeds and Spices"],
  ["Tamarind",                           250, "Gram", 3,   5,   nil,  nil, "Seeds and Spices"],
  ["Turmeric Powder",                    1,   "Kg",   nil, nil, 17,   nil, "Seeds and Spices"],
  ["Turmeric Powder",                    250, "Gram", 4,   4,   nil,  nil, "Seeds and Spices"],
  ["Turmeric Powder",                    100, "Gram", 10,  9,   nil,  nil, "Seeds and Spices"],

  # ---- CHUTNEY AND MASALA POWDERS ----
  ["Flax Seed Chutney Powder",           100, "Gram", 2,   1,   4,   nil, ""],
  ["Fried Gram Chutney Powder",          100, "Gram", 2,   25,  1,   nil, ""],
  ["Groundnut Chutney Powder",           100, "Gram", 2,   1,   nil, nil, ""],
  ["Groundnut Chutney Powder",           200, "Gram", 2,   1,   nil, nil, ""],
  ["Nizer Seeds Chutney Powder",         100, "Gram", 2,   40,  nil, nil, ""],
  ["Nizer Seeds Chutney Powder",         250, "Gram", 2,   5,   nil, nil, ""],

  # ---- MASALA POWDERS ----
  ["Puliyogare Powder",                  100, "Gram", nil, nil, nil, nil, ""],
  ["Vangibath Powder",                   100, "Gram", nil, nil, nil, nil, ""],
  ["Bisibelebath Powder",                100, "Gram", nil, nil, nil, nil, ""],
  ["Rasam Powder",                       100, "Gram", nil, nil, nil, nil, ""],
  ["Sambar Powder",                      100, "Gram", nil, nil, nil, nil, ""],

  # ---- FLOURS AND RAVA (1kg) ----
  ["Chana Flour (Besan)",                1,   "Kg",   2,   4,   nil,  nil, ""],
  ["Jave (Khapali) Wheat Flour",         1,   "Kg",   4,   7,   7,    nil, ""],
  ["Wheat Flour",                        1,   "Kg",   5,   7,   5,    nil, ""],
  ["Jowar Flour (Sorghum Atta)",         1,   "Kg",   4,   4,   3,    nil, ""],
  ["Ragi Flour",                         1,   "Kg",   4,   8,   1,    nil, ""],
  ["Rice Flour",                         1,   "Kg",   4,   5,   2,    nil, ""],
  ["Raktashali Avalakki",                500, "Kg",   4,   5,   12.5, nil, ""], # "Kg" in sheet -> likely 500 g
  ["White Avalakki",                     500, "Kg",   4,   5,   4,    nil, ""], # "Kg" in sheet -> likely 500 g
  ["Broken Corn (Nucchu)",               1,   "Kg",   nil, 7,   nil,  nil, ""], # sheet had "250G" note in central col
  ["Broken Jowar ( Jolada Nucchu)",      1,   "Kg",   nil, 3,   nil,  nil, ""],
  ["Jave (Khapali) Wheat Rava",          1,   "Kg",   nil, 5.5, 1.5,  nil, ""],
  ["Raktashali Avalakki",                0.5, "Kg",   nil, nil, nil,  nil, ""],
  ["White Avalakki",                     0.5, "Kg",   3,   nil, nil,  nil, ""],
  ["Broken Corn (Nucchu)",               0.5, "Kg",   2,   nil, nil,  nil, ""],
  ["Broken Jowar ( Jolada Nucchu)",      0.5, "Kg",   2,   nil, nil,  nil, ""],
  ["Jave (Khapali) Wheat Rava",          0.5, "Kg",   3,   nil, nil,  nil, ""],

  # ---- PICKLES ----
  ["Hadjod Pickles",                     200, "Gram", 2,   6,   nil, nil, ""],
  ["LemonPickles",                       200, "Gram", 2,   1,   nil, nil, ""],
  ["Mango Pickles",                      200, "Gram", 2,   7,   nil, nil, ""],

  # ---- HEALTHCARE ----
  ["Bramhi Powder",                      100, "Gram", nil, 1,   nil, nil, ""],
  ["Chavanprash",                        250, "Gram", 4,   9,   3,   nil, ""],
  ["Millet Mix",                         500, "Gram", 3,   nil, nil, nil, ""],
  ["Millet Mix",                         750, "Gram", 2,   5,   2,   nil, ""],
  ["Sapotas Flakes ( 500)",              100, "Gram", nil, 4,   nil, nil, ""],

  # ---- BEVERAGES AND JUICES ---- (unit "Gram" per sheet; usually means ml)
  ["Amla Juice",                         500, "Gram", 4,   9,   4,   nil, ""],
  ["Aloevera Juice",                     500, "Gram", 4,   7,   21,  nil, ""],
  ["Tulasi Juice",                       500, "Gram", 4,   3,   3,   nil, ""],
  ["Triphala Juice",                     500, "Gram", 4,   6,   3,   nil, ""],
  ["Jamun Karela Juice",                 500, "Gram", 4,   4,   2,   nil, ""],
  ["Shankupusha (Blue Pea Flowers Dried)", 50, "Gram", nil, nil, nil, nil, ""],
  ["Assam Tea",                          200, "Gram", 4,   15,  2,   nil, ""],
  ["Herbal Tea",                         100, "Gram", 4,   5,   10,  nil, ""],

  # ---- COOKIES ---- (no weight/unit in sheet)
  ["Ragi Biscuit",                       nil, nil,    6,   17,  3,   nil, ""],
  ["Wheat Biscuit",                      nil, nil,    6,   18,  nil, nil, ""],

  # ---- BODY CARE ---- (no weight/unit in sheet)
  ["Abhyanga Taila",                     nil, nil,    5,   19,  22,  nil, ""],
  ["Aloevera Soap",                      nil, nil,    10,  25,  1,   nil, ""],
  ["Chandan Soap",                       nil, nil,    20,  89,  nil, nil, ""],
  ["Charcol Mint Soap",                  nil, nil,    10,  20,  nil, nil, ""],
  ["Rose Soap",                          nil, nil,    20,  82,  nil, nil, ""],
  ["Gomaya soap",                        nil, nil,    10,  14,  nil, nil, ""],
  ["Lime Soap",                          nil, nil,    10,  nil, nil, nil, ""],
  ["Turmeric Soap",                      nil, nil,    10,  26,  nil, nil, ""],
  ["Neem Soap (Combo)",                  nil, nil,    10,  46,  nil, nil, ""],
  ["Orange Soap (Combo)",                nil, nil,    10,  23,  22,  nil, ""],
  ["Panchagavya Soap",                   nil, nil,    20,  75,  nil, nil, ""],
  ["Red Sandal Powder",                  nil, nil,    nil, 2,   nil, nil, ""], # sheet col alignment unclear
  ["Sandal Powder",                      nil, nil,    nil, 4,   nil, nil, ""], # sheet col alignment unclear
  ["Sugandhi Utane",                     nil, nil,    2,   7,   nil, nil, ""],
  ["Aayurvedic Ubtan",                   nil, nil,    4,   5,   nil, nil, ""],
  ["Wonder Bath Powder",                 nil, nil,    4,   10,  nil, nil, ""],
  ["Apple Liquid Soap",                  nil, nil,    4,   6,   nil, nil, ""],
  ["Lemon Liquid Soap",                  nil, nil,    4,   6,   nil, nil, ""],

  # ---- COSMETICS ---- (no weight/unit in sheet)
  ["Chandan Talc Powder",                nil, nil,    4,   15,  3,   nil, ""],
  ["Rose Water",                         nil, nil,    4,   17,  4,   nil, ""],
  ["Natural Kumkum",                     nil, nil,    4,   5,   nil, nil, ""],
  ["Wonder Lips",                        nil, nil,    4,   20,  2,   nil, ""],
  ["Face Pack",                          nil, nil,    4,   4,   4,   nil, ""],
  ["Natural Kajal",                      nil, nil,    4,   9,   4,   nil, ""],
  ["Multani Mitti",                      nil, nil,    4,   nil, nil, nil, ""],

  # ---- HAIR CARE ---- (no weight/unit in sheet)
  ["Bringaraj Hibiscus Hair Oil",        nil, nil,    nil, nil, nil, nil, ""],
  ["Dhantaphala Oil (100 Ml)",           nil, nil,    nil, 8,   nil, nil, ""], # sheet col alignment unclear
  ["Hair Oil (100gm)",                   nil, nil,    4,   5,   2,   nil, ""],
  ["Hair Pack",                          nil, nil,    4,   8,   2,   nil, ""],
  ["Hair wash powder (1Kg)",             nil, nil,    4,   18,  2.5, nil, ""],
  ["Hibiscus Powder",                    nil, nil,    nil, 1,   nil, nil, ""], # sheet col alignment unclear
  ["Indigo Powder",                      nil, nil,    nil, nil, nil, nil, ""],
  ["KeshNikhar Shampoo",                 nil, nil,    6,   10,  5,   nil, ""],
  ["Mehendi Powder",                     nil, nil,    4,   3.3, nil, nil, ""], # sheet had "700G" note in central col
  ["Shikakai Powder",                    nil, nil,    4,   1,   nil, nil, ""], # sheet had "2KG" note in central col
  ["Shikakai Shampoo",                   nil, nil,    10,  35,  97,  nil, ""],

  # ---- ORAL CARE ---- (no weight/unit in sheet)
  ["Charcoal Tooth Powder",              nil, nil,    4,   10,  31,  nil, ""],
  ["Siddhadant Tooth powder",            nil, nil,    4,   10,  1,   nil, ""],
  ["Siddhadant (with Basma) Toothpowder", nil, nil,   4,   6,   4,   nil, ""],
  ["Natural Mouth Wash",                 nil, nil,    3,   3,   2,   nil, ""],
  ["Siddhadant Toothpaste",              nil, nil,    10,  50,  45,  nil, ""],

  # ---- AYURVEDIC FORMULATION ----
  ["Amruthadhara (Cold)",                nil, nil,    5,   7,   9,   nil, ""],
  ["Amruthadhara (Digestion)",           nil, nil,    5,   nil, nil, nil, ""],
  ["GoGruth (Nose Drop)",                nil, nil,    5,   8,   10,  nil, ""],
  ["Gomaya Tail (Ear drop)",             1,   nil,    5,   8,   10,  nil, ""],
  ["Panchagavya Gruth",                  1,   nil,    5,   3,   nil, nil, ""],
  ["Arjun Goark (Heart)",                1,   nil,    5,   2,   14,  nil, ""],
  ["Harshringar Goark (Vata)",           1,   nil,    5,   8,   13,  nil, ""],
  ["Goark",                              1,   nil,    5,   8,   18,  nil, ""],
  ["Pashanabhed Goark (Kidney stone)",   1,   nil,    5,   8,   5,   nil, ""],
  ["Punarnova Goark (Kidney Problem)",   1,   nil,    5,   5,   3,   nil, ""],
  ["Saptrangi Goark (Diabetes)",         1,   nil,    5,   9,   8,   nil, ""],
  ["Sarpagandha Goark (BP)",             1,   nil,    5,   nil, 14,  nil, ""],
  ["Tulasi Goark (Cold and Cough)",      1,   nil,    5,   8,   nil, nil, ""],
  ["Takra Ark (Gut )",                   1,   nil,    5,   4,   nil, nil, ""],
  ["Lotion (Skin Desease)",              1,   nil,    5,   3,   1,   nil, ""],
  ["Mahanarayan Tail",                   1,   nil,    5,   2,   1,   nil, ""],
  ["Malish Tail (Massage)",              1,   nil,    5,   18,  15,  nil, ""],
  ["Niragundi (Pain Relief Oil)",        1,   nil,    5,   nil, nil, nil, ""],
  ["Migraine Oil",                       1,   nil,    5,   4,   nil, nil, ""],

  # ---- HOME CARE ----
  ["Brut Room Freshner",                 1,   nil,    2,   10,  4,   nil, ""],
  ["Dish Wash Powder",                   1,   "Kg",   4,   14,  nil, nil, ""],
  ["Jasmine Room Freshner",              1,   nil,    2,   5,   14,  nil, ""],
  ["Natural Floor Cleaner",              1,   nil,    5,   29,  2,   nil, ""],
  ["Scrub",                              1,   nil,    nil, nil, nil, nil, ""],
  ["Toilet Cleaner",                     1,   nil,    4,   11,  9,   nil, ""],

  # ---- POOJA PRODUCTS ----
  ["Agarbatti",                          1,   nil,    10,  19,  15,  nil, ""],
  ["Agnihotra Kit",                      1,   nil,    10,  2,   nil, nil, ""],
  ["Bambooless Agarbattis",              1,   nil,    10,  15,  nil, nil, ""],
  ["Dhoop Cone",                         1,   nil,    10,  1,   23,  nil, ""],
  ["Sambrani Cup",                       1,   nil,    10,  12,  30,  nil, ""],
  ["Siddhagiri Dhoop",                   1,   nil,    10,  42,  19,  nil, ""],

  # ---- MILLETS (1Kg) ---- (no weight/unit in sheet)
  ["Bajra",                              nil, nil,    3,   1,   nil, nil, ""], # sheet had "250G" note in central col
  ["Barnyard Millet",                    nil, nil,    3,   1,   1,   nil, ""],
  ["Browntop Millet",                    nil, nil,    3,   5,   nil, nil, ""],
  ["Foxtail Millet",                     nil, nil,    3,   2,   nil, nil, ""],
  ["Kodo Millet",                        nil, nil,    3,   1,   3.5, nil, ""],
  ["Little Millet",                      nil, nil,    3,   3,   3,   nil, ""],
  ["Proso Millet 500",                   nil, nil,    3,   2,   nil, nil, ""],
  ["Ragi Whole",                         nil, nil,    3,   nil, nil, nil, ""],
  ["Jowar Grain",                        nil, nil,    3,   10,  nil, nil, ""], # sheet note: "if black 0"
].freeze

NAME_ALIAS = {}
UNIT_ALIAS = { "ltr" => "liter", "l" => "liter", "ltrs" => "liter",
               "gm" => "gram", "g" => "gram", "gms" => "gram", "grams" => "gram",
               "kgs" => "kg", "kg" => "kg",
               "ml" => "ml", "mls" => "ml", "liter" => "liter", "gram" => "gram" }

def norm_unit(u) = UNIT_ALIAS[u.to_s.strip.downcase] || u.to_s.strip.downcase

store  = Store.where("name ILIKE '%Gandhi%Baz%'").first ||
         (Store.count == 1 ? Store.first : nil) or
  abort "Gandhi Bazar store not found and there is not exactly one store"
vendor = Vendor.find_by("name ILIKE 'System Default'") || Vendor.first or abort "no vendor"
puts "Store: ##{store.id} #{store.name}   Vendor: ##{vendor.id} #{vendor.name}"

log = []

ActiveRecord::Base.transaction do
  # BATCH 2 does NOT wipe — it adds on top of what scratch_seed_stock.rb seeded.
  puts "No wipe. Existing: #{StockBatch.count} batches, #{StockMovement.count} movements, #{StockTransfer.count} transfers"

  SHEET.each do |name, weight, unit, store_low, store_qty_in, central, central_low, category_name|
    lookup = NAME_ALIAS[name.downcase] || name
    product = Product.where("lower(name) = ?", lookup.downcase).first
    unless product
      log << "SKIP (no product): #{name} #{weight} #{unit}"
      next
    end

    # category (blank column -> leave as is)
    cname = category_name.to_s.strip
    unless cname.empty?
      cat = Category.find_by("lower(name) = ?", cname.downcase)
      if cat && product.category_id != cat.id
        product.update_columns(category_id: cat.id, updated_at: Time.current)
        log << "#{name}: category -> #{cat.name}"
      end
    end

    # single-variant product -> make it behave like the multi-variant ones
    if product.product_variants.count == 1 && !product.has_multiple_quantities?
      product.update_columns(has_multiple_quantities: true, updated_at: Time.current)
    end

    wanted_u = norm_unit(unit)
    variant =
      if weight.nil?
        nil
      else
        product.product_variants.detect { |v| v.weight.to_f == weight.to_f && norm_unit(v.unit) == wanted_u }
      end
    log << "#{name} #{weight} #{unit}: no variant match -> using product ##{product.id} (no variant)" if weight && !variant

    sell = (variant&.selling_price).to_f
    sell = product.price.to_f if sell <= 0
    sell = 1 if sell <= 0
    buy = (variant&.buying_price).to_f
    buy = product.buying_price.to_f if buy <= 0
    buy = sell if buy <= 0

    # ---- central (admin app) ----
    central_qty = central.to_i
    if variant
      variant.update_columns(
        available_stock: central_qty,
        low_stock_threshold: (central_low || variant.low_stock_threshold || 10),
        updated_at: Time.current
      )
      central_low_val = variant.low_stock_threshold
    else
      product.update_columns(
        stock: central_qty,
        low_stock_threshold: (central_low || product.low_stock_threshold || 10),
        updated_at: Time.current
      )
      central_low_val = product.low_stock_threshold
    end
    if central_qty > 0
      StockBatch.create!(product: product, product_variant: variant, vendor: vendor, store_id: nil,
                         quantity_purchased: central_qty, quantity_remaining: central_qty,
                         purchase_price: buy, selling_price: sell, batch_date: Date.current, status: "active")
    end

    # ---- store ----
    store_qty = store_qty_in.to_i
    si = StoreInventory.find_or_initialize_by(store_id: store.id, product_id: product.id, product_variant_id: variant&.id)
    si.quantity = store_qty
    si.low_stock_threshold = (store_low || store.auto_transfer_threshold || 10)
    si.save!
    if store_qty > 0
      StockBatch.create!(product: product, product_variant: variant, vendor: vendor, store_id: store.id,
                         quantity_purchased: store_qty, quantity_remaining: store_qty,
                         purchase_price: buy, selling_price: sell, batch_date: Date.current, status: "active")
    end

    log << format("%-38s %4s %-6s | central %-4s (low %s) | %s %-4s (low %s)",
                  name, weight, unit, central_qty, central_low_val,
                  store.name, store_qty, si.low_stock_threshold)
  end
end

puts "\n=== RESULT ==="
puts log.join("\n")
puts "\nStockBatch=#{StockBatch.count} (central #{StockBatch.central.count}, #{store.name} #{StockBatch.where.not(store_id: nil).count})  StoreInventory=#{StoreInventory.count}"
