
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Template = GetCommonTemplate(Parameters.TemplateName);
	
	HTMLDocumentField = Template.GetText();
	
	Title = Parameters.Title;
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

#EndRegion
