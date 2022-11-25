///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

Function ObjectsWithCreationBasedOnCommands() Export
	
	Objects = New Array;
	SSLSubsystemsIntegration.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	GenerationOverridable.OnDefineObjectsWithCreationBasedOnCommands(Objects);
	
	Result = New Map;
	For Each MetadataObject In Objects Do
		Result.Insert(MetadataObject.FullName(), True);
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion

