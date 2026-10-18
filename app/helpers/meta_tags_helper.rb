# Título, descrição e imagem de cada página no <head> (Google, WhatsApp, LinkedIn, X).
# Na view: <% meta title: "Votações da Câmara", description: "..." %>
# Página sem nada usa o padrão da home.
module MetaTagsHelper
  SITE_NAME = "Harpia".freeze
  HOME_TITLE = "Harpia · Estamos de olho!".freeze
  DEFAULT_DESCRIPTION = "O raio-x da política no Brasil: gastos, votações, projetos de lei e candidatos " \
                        "dos deputados federais, com dados oficiais da Câmara.".freeze
  DEFAULT_IMAGE = "/og-harpia.jpg".freeze
  DEFAULT_IMAGE_ALT = "Harpia · Estamos de olho! O raio-x da política no Brasil".freeze
  # Áreas pessoais ficam fora dos buscadores (as telas de conta, do Devise, também)
  PRIVATE_CONTROLLERS = %w[chats messages].freeze

  def meta(title: nil, description: nil, image: nil, type: nil, noindex: false)
    if title.present?
      content_for(:title, "#{title} · #{SITE_NAME}")
      content_for(:og_title, title)
    end
    content_for(:description, description.to_s.squish.truncate(200, separator: " ")) if description.present?
    content_for(:og_image, image) if image.present?
    content_for(:og_type, type) if type.present?
    content_for(:noindex, "1") if noindex
    nil
  end

  def meta_title
    content_for?(:title) ? content_for(:title) : HOME_TITLE
  end

  def meta_og_title
    content_for?(:og_title) ? content_for(:og_title) : meta_title
  end

  def meta_description
    content_for?(:description) ? content_for(:description) : DEFAULT_DESCRIPTION
  end

  def meta_og_type
    content_for?(:og_type) ? content_for(:og_type) : "website"
  end

  # Endereço oficial da página, sem filtros e paginação
  def meta_canonical_url
    request.base_url + request.path
  end

  def meta_default_image?
    !content_for?(:og_image)
  end

  def meta_image_url
    image = meta_default_image? ? DEFAULT_IMAGE : content_for(:og_image).to_s
    image.start_with?("http") ? image : request.base_url + image
  end

  def meta_noindex?
    content_for?(:noindex) || devise_controller? || PRIVATE_CONTROLLERS.include?(controller_name)
  end
end
