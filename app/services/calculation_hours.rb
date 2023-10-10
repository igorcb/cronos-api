horas = [
  ['07:02', '09:19'],
  ['09:20', '10:58'],
  ['10:59', '12:25'],
  ['12:26', '12:40'],
  ['14:00', '15:54'],
  ['15:55', '19:28'],
]

total_minutos = 0

horas.each do |inicio, fim|
  hora_inicio, minuto_inicio = inicio.split(':').map(&:to_i)
  hora_fim, minuto_fim = fim.split(':').map(&:to_i)

  diferenca_minutos = (hora_fim * 60 + minuto_fim) - (hora_inicio * 60 + minuto_inicio)

  total_minutos += diferenca_minutos
end

# Agora, vamos converter o total de minutos em horas e minutos e formatar a saída
total_horas = total_minutos / 60
resto_minutos = total_minutos % 60

puts format('%02d:%02d', total_horas, resto_minutos)
