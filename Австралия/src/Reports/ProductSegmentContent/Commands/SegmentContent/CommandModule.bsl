
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If Not ValueIsFilled(CommandParameter) Then
		Return;
	EndIf;
	
	If GroupIsSelected(CommandParameter) Then
		Raise NStr("en = 'Cannot generate for a segment group.'; ru = 'Невозможно сгенерировать для группы сегментов.';pl = 'Generacja grupy segmentów jest niemożliwe.';es_ES = 'No se ha podido generar para un grupo de segmento.';es_CO = 'No se ha podido generar para un grupo de segmento.';tr = 'Segment grubu için oluşturulamıyor.';it = 'Non è possibile generare per un gruppo segmento.';de = 'Für eine Segmentgruppe kann nicht generiert werden.'");
	EndIf;
	
	ReportParametersAndFilter = New Structure("Segment", CommandParameter);
	
	FormParameters = New Structure();
	FormParameters.Insert("VariantKey", "ProductSegmentContentContext");
	FormParameters.Insert("Filter", ReportParametersAndFilter);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("ReportVariantsCommandVisible", False);
	FormParameters.Insert("CloseAtOwnerClose", True);
	
	OpenForm(
		"Report.ProductSegmentContent.Form", 
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

&AtServer
Function GroupIsSelected(Segment)
	Return Common.ObjectAttributeValue(Segment, "IsFolder");
EndFunction
