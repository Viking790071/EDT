#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Owner) Then
		AdditionalValuesOwner = Common.ObjectAttributeValue(Owner,
			"AdditionalValuesOwner");
		
		If ValueIsFilled(AdditionalValuesOwner) Then
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Дополнительные значения для свойства ""%1"", созданного
				           |по образцу свойства ""%2"" нужно создавать для свойства-образца.'; 
				           |en = 'Additional values for the ""%1"" property created
				           |by sample of the ""%2"" property are to be created for the sample property.'; 
				           |pl = 'Dodatkowe wartości właściwości ""%1"" utworzonej według
				           |wzoru właściwości ""%2"" należy tworzyć dla wzorcowej właściwości.';
				           |es_ES = 'Valores adicionales para la propiedad ""%1"" creada
				           | en el modelo de la propiedad ""%2"" tienen que crearse para la propiedad de modelo.';
				           |es_CO = 'Valores adicionales para la propiedad ""%1"" creada
				           | en el modelo de la propiedad ""%2"" tienen que crearse para la propiedad de modelo.';
				           |tr = 'Örnek özelliği için%2 "
" özellik kalıbı kullanılarak oluşturulan ""%1"" özelliği için ek değerler oluşturulmalıdır.';
				           |it = 'Creato valore aggiuntivo per la proprietà ""%1""
				           |per esempio della proprietà ""%2"" dovrebbero essere creati per la proprietà esempio.';
				           |de = 'Zusätzliche Werte für die Eigenschaft ""%1"", die auf dem
				           |Modell der Eigenschaft ""%2"" erstellt wurde, müssen für die Mustereigenschaft erstellt werden.'"),
				Owner,
				AdditionalValuesOwner);
			
			If IsNew() Then
				Raise ErrorDescription;
			Else
				CommonClientServer.MessageToUser(ErrorDescription);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
