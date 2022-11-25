#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Title = NStr("en = 'Select replenishment methods'; ru = 'Укажите способ пополнения';pl = 'Wybierz sposoby uzupełniania';es_ES = 'Seleccione métodos de reposición del inventario';es_CO = 'Seleccione métodos de reposición del inventario';tr = 'Stok yenileme yöntemlerini seç';it = 'Selezionare metodo di rifornimento';de = 'Auffüllungsmethoden auswählen'");
	
	For Each DocKeyAndValue In Parameters.ReplenishmentMethod Do
		
		NewRow = ReplenishmentMethods.Add();
		NewRow.Check = DocKeyAndValue.Check;
		NewRow.ReplenishmentMethod = DocKeyAndValue.Value;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Save(Command)
	
	Close(ConvertValueTableToValueList());
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ConvertValueTableToValueList()
	
	ValueList = New ValueList;
	
	For Each RowValueTable In ReplenishmentMethods Do
		ValueList.Add(RowValueTable.ReplenishmentMethod,,RowValueTable.Check)
	EndDo;

	Return ValueList;
	
EndFunction

#EndRegion