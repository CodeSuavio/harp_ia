class AddActionsToMessages < ActiveRecord::Migration[8.1]
  # Próximos passos oferecidos pela Harpia abaixo da resposta, como botões:
  # perguntas que ela mesma responde ou páginas da plataforma
  # ({ "type" => "question" | "link", "label" => ..., "value" => pergunta ou caminho }).
  #
  # page_path: caminho da página em que a pergunta foi feita, para a Harpia
  # não oferecer um link para a página em que o usuário já está.
  def change
    add_column :messages, :actions, :jsonb, null: false, default: []
    add_column :messages, :page_path, :string
  end
end
