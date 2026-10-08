class CreateThemesAndProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :themes do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :keywords
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :themes, :slug, unique: true

    # Classificação automática (por palavras-chave) de projetos e votações em temas
    create_table :bill_themes do |t|
      t.references :bill, null: false, foreign_key: true
      t.references :theme, null: false, foreign_key: true
    end
    add_index :bill_themes, [:bill_id, :theme_id], unique: true

    create_table :poll_themes do |t|
      t.references :poll, null: false, foreign_key: true
      t.references :theme, null: false, foreign_key: true
    end
    add_index :poll_themes, [:poll_id, :theme_id], unique: true

    # Propostas (programa do partido, plano de governo do candidato do partido
    # ao Executivo ou propostas de campanha do próprio deputado)
    create_table :proposals do |t|
      t.string :source_kind, null: false
      t.string :author
      t.references :theme, null: false, foreign_key: true
      t.references :party, foreign_key: true
      t.references :deputy, foreign_key: true
      t.string :state_label
      t.string :title, null: false
      t.text :excerpt
      t.string :source_url
      t.timestamps
    end

    # Votações ligadas a uma proposta, com o voto que cumpre a proposta
    create_table :proposal_polls do |t|
      t.references :proposal, null: false, foreign_key: true
      t.references :poll, null: false, foreign_key: true
      t.string :favorable_vote, null: false
    end
    add_index :proposal_polls, [:proposal_id, :poll_id], unique: true
  end
end
