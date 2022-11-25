#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If IsProductionBOM(CommandParameter) Then
		
		FormParameters = New Structure("BillOfMaterials", CommandParameter);
		OpenForm(
			"Catalog.BillsOfMaterials.Form.BillsOfMaterialsWithStages",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL);
		
	Else
		
		CommonClientServer.MessageToUser(NStr("en = 'BOM explosion is available only for BOMs whose Process type is Production.'; ru = 'Разбивка спецификации доступна только для спецификаций изделий с типом процесса ""Производство"".';pl = 'Podział specyfikacji materiałowej jest dostępny tylko dla tych specyfikacji materiałowych, Typem produkcji których jest Produkcja.';es_ES = 'El desglose de la lista de materiales sólo está disponible para las listas de materiales cuyo Tipo de proceso es Producción.';es_CO = 'El desglose de la lista de materiales sólo está disponible para las listas de materiales cuyo Tipo de proceso es Producción.';tr = 'Ürün reçetesi açılımı sadece Süreç türü Üretim olan Ürün reçeteleri için kullanılabilir.';it = 'L''esplosione della distinta base è disponibile solo per le distinte base il cui tipo di Processo è Produzione.';de = 'Stücklistenauflösung ist nur für Stücklisten mit dem Prozesstyp ""Produktion"".'"));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function IsProductionBOM(BOM)
	
	Return (Common.ObjectAttributeValue(BOM, "OperationKind") = Enums.OperationTypesProductionOrder.Production);
	
EndFunction

#EndRegion
