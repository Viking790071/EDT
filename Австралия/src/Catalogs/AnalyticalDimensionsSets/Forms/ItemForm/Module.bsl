
#Region FormTableItemsEventHandlersAnalyticalDimensions

&AtClient
Procedure AnalyticalDimensionsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	MaxAnalyticalDimensionsNumber = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	If Object.AnalyticalDimensions.Count() >= MaxAnalyticalDimensionsNumber Then
		
		ErrorMessage = StrTemplate(
			NStr("en = 'The number of analytical dimensions cannot exceed %1.'; ru = 'Количество аналитических измерений не может превышать %1.';pl = 'Ilość wymiarów analitycznych nie może przekraczać %1.';es_ES = 'El número de dimensiones analíticas no puede ser superior a %1.';es_CO = 'El número de dimensiones analíticas no puede ser superior a %1.';tr = 'Analitik boyutların sayısı en fazla %1 olabilir.';it = 'Il numero di dimensioni analitiche non può superare %1.';de = 'Die Nummer von analytischen Messungen kann %1 nicht übersteigen.'"),
			Lower(TrimAll(NumberInWords(MaxAnalyticalDimensionsNumber, "FN=False", ", , , , 0"))));
		CommonClientServer.MessageToUser(ErrorMessage, , , , Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion