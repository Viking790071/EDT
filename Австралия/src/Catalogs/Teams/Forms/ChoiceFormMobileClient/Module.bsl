#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ArrayTeams") Then
		ListTeams = New ValueList;
		ListTeams.LoadValues(Parameters.ArrayTeams);
		DriveClientServer.SetListFilterItem(List, "Ref", ListTeams, True, DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure

#EndRegion