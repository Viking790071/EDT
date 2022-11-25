#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("CreateGoodsIssue") Then
		CreateGoodsIssue = Number(Parameters.CreateGoodsIssue);
	Endif;
	
	If Parameters.Property("PostDocuments") Then
		PostAutomaticaly = Parameters.PostDocuments;
	Endif;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SaveClose(Command)
	
	StructureOfSettings = New Structure;
	StructureOfSettings.Insert("CreateGoodsIssue", Boolean(CreateGoodsIssue));
	StructureOfSettings.Insert("PostDocuments", PostAutomaticaly);
	
	Close(StructureOfSettings);
	
EndProcedure

#EndRegion