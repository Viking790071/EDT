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
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		FilterItem = Parameters.Filter.Owner;
		Parameters.Filter.Delete("Owner");
	Else
		FilterItem = Users.AuthorizedUser();
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Owner",
		FilterItem,
		DataCompositionComparisonType.Equal);
EndProcedure

#EndRegion
