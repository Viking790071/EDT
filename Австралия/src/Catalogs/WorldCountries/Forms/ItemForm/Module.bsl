
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Object.Predefined Then
		Items.DescriptionGroup.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Catalog.WorldCountries.Update", Object.Ref, ThisObject);
EndProcedure

#EndRegion
