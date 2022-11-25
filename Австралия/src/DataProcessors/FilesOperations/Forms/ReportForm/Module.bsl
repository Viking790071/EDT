
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Report = FilesOperationsInternalServerCall.FilesImportGenerateReport(
		Parameters.ArrayOfFilesNamesWithErrors);
	
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReportChoice(Item, Area, StandardProcessing)
	
#If Not WebClient Then
	// Path to file.
	If StrFind(Area.Text, ":\") > 0 OR StrFind(Area.Text, ":/") > 0 Then
		FilesOperationsInternalClient.OpenExplorerWithFile(Area.Text);
	EndIf;
#EndIf
	
EndProcedure

#EndRegion
