module GastosHelper
  # A fonte (harpia-seed-data) traz no máximo 120 lançamentos por deputado, os de maior valor
  LIMITE_DA_FONTE = 120

  # { lancamentos:, meses:, parcial:, poucos_meses: } das despesas do deputado no ano
  def cobertura_de_gastos(deputy, year)
    escopo = Expense.where(deputy_id: deputy.id, year: year)
    lancamentos = escopo.count
    meses = escopo.distinct.count(:month)
    { lancamentos: lancamentos, meses: meses,
      parcial: lancamentos >= LIMITE_DA_FONTE, poucos_meses: meses.between?(1, 2) }
  end
end
