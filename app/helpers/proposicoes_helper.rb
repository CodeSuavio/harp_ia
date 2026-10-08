module ProposicoesHelper
  def proposicao_label(bill)
    if bill.bill_type.present? && bill.number.present?
      "#{bill.bill_type} #{bill.number}/#{bill.year}"
    else
      "Proposição nº #{bill.bill_number}"
    end
  end
end
