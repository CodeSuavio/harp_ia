# Busca sem diferenciar acentos em "Meus Chats" ("votacao" encontra "votação").
class EnableUnaccent < ActiveRecord::Migration[8.1]
  def change
    enable_extension "unaccent"
  end
end
