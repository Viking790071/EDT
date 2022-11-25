
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("UseFilledSKU") Then
		UseFilledSKU = Parameters.UseFilledSKU;
	EndIf;
	
	SetFilterOfList();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetFilterOfList()
	
	If UseFilledSKU Then
		CommonClientServer.SetFilterItem(List.Filter, "SKU", "", DataCompositionComparisonType.NotEqual);
	EndIf;
	
EndProcedure

#EndRegion
