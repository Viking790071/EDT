///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalParameters = New Structure("MessageSourceFormName", "");
	If TypeOf(CommandExecuteParameters.Source) = Type("ClientApplicationForm") Then
		AdditionalParameters.MessageSourceFormName = CommandExecuteParameters.Source.FormName;
	EndIf;
	
	MessageTemplatesClient.GenerateMessage(CommandParameter, "Email",,, AdditionalParameters);
EndProcedure

#EndRegion
