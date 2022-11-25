///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "IsFolder", True,
		DataCompositionComparisonType.Equal, , ,
		DataCompositionSettingsItemViewMode.Normal);
EndProcedure

#EndRegion
