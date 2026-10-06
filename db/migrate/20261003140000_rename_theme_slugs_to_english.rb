# Os slugs aparecem na URL (?theme=) e no JSON de importação de propostas: padrão em inglês.
# Renomeia em vez de recriar, para manter as propostas e classificações ligadas aos temas.
class RenameThemeSlugsToEnglish < ActiveRecord::Migration[8.1]
  SLUGS = {
    "saude" => "health", "educacao" => "education", "seguranca" => "public-security",
    "economia" => "economy", "trabalho" => "labor", "meio-ambiente" => "environment",
    "agro" => "agriculture", "direitos-humanos" => "human-rights", "infraestrutura" => "infrastructure",
    "assistencia" => "social-assistance", "cultura" => "culture", "transparencia" => "transparency",
    "tecnologia" => "technology", "consumidor" => "consumer", "animais" => "animal-welfare",
    "homenagens" => "tributes"
  }.freeze

  def up
    SLUGS.each { |old, new| execute "UPDATE themes SET slug = #{quote(new)} WHERE slug = #{quote(old)}" }
  end

  def down
    SLUGS.each { |old, new| execute "UPDATE themes SET slug = #{quote(old)} WHERE slug = #{quote(new)}" }
  end

  private

  def quote(value) = connection.quote(value)
end
