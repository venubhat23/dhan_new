class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.text :description
      t.string :document_type, null: false
      t.string :uploaded_by, null: false
      t.references :documentable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
