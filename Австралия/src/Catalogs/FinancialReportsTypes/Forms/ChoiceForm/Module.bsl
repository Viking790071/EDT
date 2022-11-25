
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ExcludeReports") Then
		ExcludeReports = Parameters.ExcludeReports;
		If TypeOf(ExcludeReports) = Type("ValueList") Or TypeOf(ExcludeReports) = Type("Array") Then
			ExcludeReportsComparisonType = DataCompositionComparisonType.NotInList;
		Else
			ExcludeReportsComparisonType = DataCompositionComparisonType.NotEqual;
		EndIf;
		CommonClientServer.SetDynamicListFilterItem(List, "Ref", ExcludeReports, ExcludeReportsComparisonType);
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
