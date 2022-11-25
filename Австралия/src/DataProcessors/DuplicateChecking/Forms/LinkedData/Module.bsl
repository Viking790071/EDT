
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	LinkedDataAddress = Parameters.LinkedDataAddress;
	LinkedData.Load(GetFromTempStorage(LinkedDataAddress));
	DeleteEmptyRows();

EndProcedure

#EndRegion

#Region LinkedDataFormTableItemsEventHandlers

&AtClient
Procedure LinkedDataSelection(Item, SelectedRow, Field, StandardProcessing)
	ShowValue(, Item.CurrentData.Data);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure DeleteEmptyRows()
	
	EmptyFilter = New Structure;
	EmptyFilter.Insert("Data", Undefined);
	RowsToDel = LinkedData.FindRows(EmptyFilter);
	
	For Each RowToDel In RowsToDel Do
		LinkedData.Delete(RowToDel);
	EndDo;
	
EndProcedure

#EndRegion
