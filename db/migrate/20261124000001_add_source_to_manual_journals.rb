# Auto-generated journals: sales invoices, customer payments, vendor purchases
# and vendor payments each post a system journal linked back to its source
# document. They're kept out of Profit & Loss (which already reads those
# documents directly) so nothing is double counted.
class AddSourceToManualJournals < ActiveRecord::Migration[8.0]
  ACCOUNTS = {
    'Sales'           => ['income', 'Product sales (auto journals from invoices)'],
    'Shipping Charge' => ['income', 'Delivery charges billed to customers'],
    'Inventory Asset' => ['asset',  'Stock bought from vendors (auto journals from purchases)']
  }.freeze

  def up
    add_column :manual_journals, :source_type, :string
    add_column :manual_journals, :source_id, :bigint
    add_column :manual_journals, :entry_kind, :string
    add_index :manual_journals, [:source_type, :source_id, :entry_kind], unique: true,
              where: 'source_type IS NOT NULL', name: 'index_manual_journals_on_source'

    ACCOUNTS.each do |name, (type, desc)|
      next if select_value("SELECT 1 FROM ledger_accounts WHERE LOWER(name) = #{quote(name.downcase)}")
      execute "INSERT INTO ledger_accounts (name, account_type, description, active, system, created_at, updated_at) " \
              "VALUES (#{quote(name)}, #{quote(type)}, #{quote(desc)}, TRUE, TRUE, NOW(), NOW())"
    end
  end

  def down
    execute "DELETE FROM manual_journal_lines WHERE manual_journal_id IN (SELECT id FROM manual_journals WHERE source_type IS NOT NULL)"
    execute "DELETE FROM manual_journals WHERE source_type IS NOT NULL"
    remove_index :manual_journals, name: 'index_manual_journals_on_source'
    remove_column :manual_journals, :entry_kind
    remove_column :manual_journals, :source_id
    remove_column :manual_journals, :source_type
  end
end
