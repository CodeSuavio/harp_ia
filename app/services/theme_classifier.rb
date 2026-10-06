# Classifica projetos de lei e votações em temas a partir de palavras-chave.
#
# A classificação é automática e pode errar; as telas avisam isso ao usuário.
# Palavras terminadas em "*" casam como prefixo ("hospita*" → hospital, hospitalar);
# as demais só casam com a palavra inteira (evita "sus" casar com "suspensão").
#
# As votações não têm descrição útil ("Aprovado o Parecer."), então herdam o tema
# do projeto de lei votado e, quando houver, do texto da própria votação.
class ThemeClassifier
  CATALOG = [
    ["Saúde", "health", "saude, sus, hospita*, medic*, medicament*, vacina*, doenca*, enfermag*, sanitari*, epidemi*, cancer, oncolog*, plano de saude"],
    ["Educação", "education", "educa*, escola*, ensino, professor*, universidade*, estudant*, aluno*, creche*, alfabetiza*, enem, fies"],
    ["Segurança pública", "public-security", "seguranca publica, policia*, crime*, criminal*, penal, penais, violencia*, arma, armas, presidio*, prisional, trafico*, homicidio*, feminicidio*"],
    ["Economia e tributos", "economy", "tribut*, imposto*, fiscal*, orcament*, economi*, empresa*, microempre*, credito*, juros, financ*, bancari*, cambi*, inflacao"],
    ["Trabalho e previdência", "labor", "trabalh*, salari*, previdenc*, aposentad*, sindica*, clt, emprego*, desemprego, fgts"],
    ["Meio ambiente", "environment", "meio ambiente, ambienta*, florest*, desmatamento*, clima*, sustentab*, poluic*, residuo*, saneamento, recursos hidricos, queimada*, amazonia"],
    ["Agropecuária", "agriculture", "agro*, rural*, agricult*, pecuari*, produtor rural, agrotoxico*, pesca*, safra*, fundiari*"],
    ["Direitos humanos e minorias", "human-rights", "direitos humanos, mulher*, igualdade, racia*, racismo, discrimina*, indigena*, quilombola*, lgbt*, deficiencia, idoso*, crianca*, adolescente*, genero"],
    ["Infraestrutura e transporte", "infrastructure", "rodovi*, transport*, infraestrutura, energia, eletric*, ferrovi*, mobilidade, aeroport*, portuari*, obras publicas, transito"],
    ["Assistência social e moradia", "social-assistance", "assistencia social, bolsa familia, pobreza, fome, auxilio*, beneficio de prestacao continuada, habitac*, moradia*, minha casa"],
    ["Cultura, esporte e turismo", "culture", "cultur*, esport*, turis*, artist*, patrimonio historico, museu*, cinema*"],
    ["Transparência e administração pública", "transparency", "transparencia, corrupc*, improbidade, licitac*, administracao publica, servidor* publico*, controle externo, acesso a informacao, eleitora*, partido* politico*"],
    ["Tecnologia e comunicação", "technology", "tecnologi*, internet, digital, digitais, dados pessoais, inteligencia artificial, telecomunica*, redes sociais, ciberne*, plataforma* digita*"],
    ["Consumidor", "consumer", "consumidor*, defesa do consumidor, procon"],
    ["Proteção animal", "animal-welfare", "animal, animais, maus-tratos, fauna"],
    ["Homenagens e datas comemorativas", "tributes", "data comemorativa, homenage*, dia nacional, semana nacional, denominac*, titulo honorifico, patrono, patrona, heroi*, heroina*"]
  ].freeze

  # Cria/atualiza os temas do catálogo sem apagar propostas já ligadas a eles
  def self.sync_catalog!
    CATALOG.each_with_index do |(name, slug, keywords), position|
      theme = Theme.find_or_initialize_by(slug: slug)
      theme.update!(name: name, keywords: keywords, position: position)
    end
  end

  def self.normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/\s+/, " ")
  end

  def initialize(themes = Theme.all)
    @matchers = themes.to_h { |theme| [theme.id, matcher_for(theme)] }.compact_blank
  end

  def theme_ids_for(*texts)
    text = self.class.normalize(texts.compact.join(" "))
    @matchers.select { |_, regex| regex.match?(text) }.keys
  end

  # Refaz toda a classificação. Retorna quantos vínculos foram criados.
  def classify_all!
    bill_rows = []
    bill_theme_ids = {}
    Bill.find_each do |bill|
      ids = theme_ids_for(bill.keywords, bill.summary)
      bill_theme_ids[bill.id] = ids
      ids.each { |theme_id| bill_rows << { bill_id: bill.id, theme_id: theme_id } }
    end

    poll_rows = []
    Poll.find_each do |poll|
      ids = (theme_ids_for(poll.description) + bill_theme_ids.fetch(poll.bill_id, [])).uniq
      ids.each { |theme_id| poll_rows << { poll_id: poll.id, theme_id: theme_id } }
    end

    ActiveRecord::Base.transaction do
      BillTheme.delete_all
      PollTheme.delete_all
      bill_rows.each_slice(5_000) { |rows| BillTheme.insert_all(rows) }
      poll_rows.each_slice(5_000) { |rows| PollTheme.insert_all(rows) }
    end

    { bills: bill_rows.size, polls: poll_rows.size }
  end

  private

  def matcher_for(theme)
    patterns = theme.keyword_list.map do |keyword|
      keyword = self.class.normalize(keyword)
      if keyword.end_with?("*")
        "\\b#{Regexp.escape(keyword.delete_suffix('*')).gsub('\\*', '\\w*')}"
      else
        "\\b#{Regexp.escape(keyword)}\\b"
      end
    end
    Regexp.new(patterns.join("|")) if patterns.any?
  end
end
