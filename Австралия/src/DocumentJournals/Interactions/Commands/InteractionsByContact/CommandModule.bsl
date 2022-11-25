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
	
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Contact", CommandParameter);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("InteractionType", "Contact");
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("AdditionalParameters", AdditionalParameters);
	
	
	OpenForm(
		"DocumentJournal.Interactions.Form.ParametricListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Source.UniqueKey,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
