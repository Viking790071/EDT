#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SubsystemSettings = InfobaseUpdateInternal.SubsystemSettings();
	TooltipText      = SubsystemSettings.UpdateResultNotes;
	
	If Not IsBlankString(TooltipText) Then
		Items.ToolTip.Title = TooltipText;
	EndIf;
	
	MessageParameters  = SubsystemSettings.UncompletedDeferredHandlersMessageParameters;
	
	If ValueIsFilled(MessageParameters.MessageText) Then
		Items.Message.Title = MessageParameters.MessageText;
	EndIf;
	
	If MessageParameters.MessagePicture <> Undefined Then
		Items.Picture.Picture = MessageParameters.MessagePicture;
	EndIf;
	
	If MessageParameters.ProhibitContinuation Then
		Items.FormContinue.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExitApplication(Command)
	Close(False);
EndProcedure

&AtClient
Procedure ContinueUpdate(Command)
	Close(True);
EndProcedure

#EndRegion
