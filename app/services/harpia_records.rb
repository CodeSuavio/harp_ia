# Deputados e partidos que as ferramentas devolveram numa resposta da Harpia.
#
# As ferramentas (app/tools) registram aqui os deputados e partidos dos dados
# consultados, com o id. Depois da resposta, ficam só os que o texto
# apresentou ao usuário (presented_in): é a eles que "esses deputados", "qual
# deles" ou "os dois" se referem nas perguntas seguintes.
#
# Apresentado = citado no texto: o deputado pelo nome (ou pelo primeiro nome,
# quando nenhum outro deputado consultado o tem) e o partido pela sigla, mas
# não quando a sigla só acompanha um deputado ("Welter (PT-PR)") ou é o tipo
# de um projeto ("PL 1234/2025").
class HarpiaRecords
  Record = Struct.new(:type, :id, :name, keyword_init: true)

  # Palavras que acompanham o nome sem identificar o deputado sozinhas
  TITLES = %w[Cabo Capitão Coronel Delegada Delegado Deputada Deputado Dr Dra Doutor Doutora General Irmão Juiz
              Juíza Major Missionário Padre Pastor Pastora Policial Professor Professora Sargento Subtenente
              Tenente].freeze
  # UFs que acompanham a sigla do partido de um deputado ("PT-PR")
  STATES = %w[AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO].freeze

  def initialize
    @records = {}
  end

  def deputy(deputy)
    add("deputy", deputy&.id, deputy&.name)
  end

  def party(party)
    add("party", party&.id, party&.label)
  end

  def all = @records.values

  # [{ "type" => "deputy", "id" => 1, "name" => "Welter" }] na ordem em que
  # aparecem no texto
  def presented_in(text)
    text = text.to_s
    all.filter_map { |record| [position(record, text), record] }
       .select(&:first).sort_by(&:first)
       .map { |_, record| record.to_h.transform_keys(&:to_s) }
  end

  private

  def add(type, id, name)
    @records[[type, id]] ||= Record.new(type: type, id: id, name: name) if id && name.present?
    nil
  end

  # Posição da primeira menção no texto, ou nil
  def position(record, text)
    return text =~ party_pattern(record.name) if record.type == "party"

    [record.name, short_name(record)].compact.filter_map { |name| text =~ word_pattern(name) }.min
  end

  # Primeiro nome sem os títulos ("Nikolas" para Nikolas Ferreira, "Palumbo"
  # para Delegado Palumbo), quando nenhum outro deputado consultado o tem
  def short_name(record)
    short = (record.name.split - TITLES).first
    return if short.nil? || short == record.name || short.size < 3

    others = all.select { |other| other.type == "deputy" && !other.equal?(record) }
    short unless others.any? { |other| other.name.split.include?(short) }
  end

  def word_pattern(name)
    /(?<![[:alnum:]])#{Regexp.escape(name)}(?![[:alnum:]])/
  end

  # Sigla fora de "(PT-PR)", "(PT)", "PT-PR" e "PL 1234/2025", como a base
  # guarda ou como se escreve ("PCdoB", "Rede"), mas com inicial maiúscula:
  # "novo" ou "rede" no meio da frase não são partidos
  def party_pattern(label)
    /(?<![[:alnum:](])(?=\p{Lu})(?i:#{Regexp.escape(label)})(?![[:alnum:]]|-(?:#{STATES.join('|')})\b|\s*\d)/
  end
end
