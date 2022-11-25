
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Property("CurrentFolder") Then
		Items.List.CurrentRow = Parameters.CurrentFolder;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		For each FormItem In Items.CommandBar.ChildItems Do
			
			Items.Move(FormItem, Items.CommandBarForm);
			
		EndDo;
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Visible", False);
		
	EndIf;
	
EndProcedure

#EndRegion
