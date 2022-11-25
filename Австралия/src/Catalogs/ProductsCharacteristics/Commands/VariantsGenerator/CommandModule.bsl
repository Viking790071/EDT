
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If DriveClient.ReadAttributeValue_IsFolder(CommandParameter) Then
		Return;
	EndIf;

	If UseCharacteristics(CommandParameter) Then
		
		RefreshProductsCharacteristics = New NotifyDescription("RefreshProductsCharacteristics",
			ThisObject);
			
		FormParameters = New Structure("Products", CommandParameter);
		OpenForm(
			"DataProcessor.VariantsGenerator.Form.Form",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL,
			RefreshProductsCharacteristics);
		
	Else
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'The products are not accounted by variants.
							|Select the ""Use variants"" check box in products card'; 
							|ru = 'Для номенклатуры не ведется учет по вариантам!
							|Установите флаг ""Использовать варианты"" в карточке номенклатуры';
							|pl = 'Produkty nie są rozliczane według wariantów.
							|Zaznacz pole wyboru ""Używaj wariantów"" na karcie Produkty';
							|es_ES = 'Los productos no se contabilizan por variantes
							|Seleccionar la casilla de verificación ""Utilizar variantes"" en la tarjeta de productos';
							|es_CO = 'Los productos no se contabilizan por variantes
							|Seleccionar la casilla de verificación ""Utilizar variantes"" en la tarjeta de productos';
							|tr = 'Ürünler değişkenlere göre hesaba katılmaz! 
							|Ürün kartında ""Varyantları kullan"" onay kutusunu seçin';
							|it = 'Gli articoli non sono contabilizzati per varianti.
							|Selezionare la casella di controllo ""Utilizza varianti"" nella scheda articolo';
							|de = 'Die Produkte sind nicht nach Varianten abgerechnet.
							|Aktivieren Sie das Kontrollkästchen ""Varianten verwenden"" auf der Produktkarte.'");
		Message.Message();
		Cancel = True;
	
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure RefreshProductsCharacteristics(Result, AdditionalParameters) Export
	
	Notify("RefreshProductsCharacteristics");

EndProcedure

&AtServer
Function UseCharacteristics(Products)
	
	Return Common.ObjectAttributeValue(Products, "UseCharacteristics");
	
EndFunction

#EndRegion