module VotacoesHelper
  def poll_result_badge(poll)
    if poll.description.to_s.start_with?("Mantido o texto")
      tag.span("Texto mantido", class: "badge text-bg-secondary", title: "A tentativa de alterar o texto não passou e o texto original foi mantido")
    elsif poll.approval == true
      tag.span("Aprovada", class: "badge text-bg-success")
    elsif poll.approval == false
      tag.span("Rejeitada", class: "badge text-bg-danger")
    end
  end
end
