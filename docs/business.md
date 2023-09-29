### Regra de Negócios do Card

## Card

* Cria um card o status vai ser **opened**
* Quando terminar um card colocar o status para **finalized**
* Reabrir um card colocar o status para **reopen**
* Quando mover para a coluna Entregue no Trello, status para **delivered** e date_delivered
* Contabilizar o total de horas dos itens

## Card Item

* Registrar a hora de inicio e fim
* Criar um item o status vai ser **pending**
* Terminar um item status vai ser **finalized**
* Quando esse ultimo item for finalizado, colocar o status do card como **finalized**
* Caso o card volte de homologacao colocar o status do card como reopened e cria novo item
