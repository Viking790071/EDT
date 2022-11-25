
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FileInfobase = Common.FileInfobase();
	If FileInfobase Then
		UpdateOrderTemplate = DataProcessors.PlatformUpdateRecommended.GetTemplate("FileInfobaseUpdateOrder");
	Else
		UpdateOrderTemplate = DataProcessors.PlatformUpdateRecommended.GetTemplate("ClientServerInfobaseUpdateOrder");
	EndIf;
	
	ApplicationUpdateOrder = UpdateOrderTemplate.GetText();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ApplicationUpdateOrderOnClick(Item, EventData, StandardProcessing)
	If EventData.Href <> Undefined Then
		StandardProcessing = False;
		CommonClient.OpenURL(EventData.Href);
	EndIf;
EndProcedure

&AtClient
Procedure PrintGuide(Command)
	Items.ApplicationUpdateOrder.Document.execCommand("Print");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ApplicationUpdateOrderDocumentGenerated(Item)
	// Print command visibility
	If Not Item.Document.queryCommandSupported("Print") Then
		Items.PrintGuide.Visible = False;
	EndIf;
EndProcedure

#EndRegion