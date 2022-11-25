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
	
	Basis = New Structure("Basis,Command", CommandParameter, "ReplyToAll");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.Form.DocumentForm", OpeningParameters);
	CommandExecuteParameters.Source.Close();
	
EndProcedure

#EndRegion