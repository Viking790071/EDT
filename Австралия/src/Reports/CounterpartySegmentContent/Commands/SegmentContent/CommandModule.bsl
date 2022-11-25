
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If Not ValueIsFilled(CommandParameter) Then
		Return;
	EndIf;
	
	If GroupIsSelected(CommandParameter) Then
		Raise NStr("en = 'Cannot select a segment group.'; ru = 'Нельзя выбирать группу сегментов.';pl = 'Nie można wybrać segmentu grupy.';es_ES = 'No se puede seleccionar un grupo de segmentos.';es_CO = 'No se puede seleccionar un grupo de segmentos.';tr = 'Bir segment grubu seçilemiyor.';it = 'Non è possibile selezione un segmento del gruppo';de = 'Kann keine Segmentgruppe auswählen.'");
	EndIf;
	
	ReportParametersAndFilter = New Structure("Segment", CommandParameter);
	
	FormParameters = New Structure();
	FormParameters.Insert("VariantKey", "SegmentContentContext");
	FormParameters.Insert("Filter", ReportParametersAndFilter);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("ReportVariantsCommandVisible", False);
	FormParameters.Insert("CloseAtOwnerClose", True);
	
	OpenForm(
		"Report.CounterpartySegmentContent.Form", 
		FormParameters,
		CommandExecuteParameters.Source,
		True,
		CommandExecuteParameters.Window);
	
EndProcedure

&AtServer
Function GroupIsSelected(Segment)
	Return Common.ObjectAttributeValue(Segment, "IsFolder");
EndFunction
