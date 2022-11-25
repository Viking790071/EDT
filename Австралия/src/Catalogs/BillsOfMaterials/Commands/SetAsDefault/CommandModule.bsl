
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If ChangeProductOwnerSpecification(CommandParameter) Then
		
		Notify("BOMSetAsDefault", CommandParameter);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
// Procedure - writes new value in product
Function ChangeProductOwnerSpecification(NewBOMByDefault)
	
	ProductOwner = Common.ObjectAttributeValue(NewBOMByDefault, "Owner");
	
	Result = False;
	
	If NewBOMByDefault.Status = Enums.BOMStatuses.Closed Then
		
		MessageText = NStr("en = 'The BOM is closed. Please select an active BOM.'; ru = 'Эта спецификация закрыта. Выберите активную спецификацию.';pl = 'Specyfikacja materiałowa jest zamknięta. Proszę wybrać aktywną specyfikację materiałową.';es_ES = 'El BOM está cerrado. Por favor, seleccione el BOM activo.';es_CO = 'El BOM está cerrado. Por favor, seleccione el BOM activo.';tr = 'Ürün reçetesi kapalı. Lütfen, aktif bir ürün reçetesi seçin.';it = 'La distinta base è chiusa. Selezionare una distinta base attiva.';de = 'Die Stückliste ist geschlossen. Wählen Sie bitte eine aktive Stückliste.'");
		CommonClientServer.MessageToUser(MessageText);
		Return Result;
		
	ElsIf NewBOMByDefault.Status = Enums.BOMStatuses.Open Then
		
		MessageText = NStr("en = 'The BOM is open. Please select an active BOM.'; ru = 'Эта спецификация открыта. Выберите активную спецификацию.';pl = 'Specyfikacja materiałowa jest otwarta. Proszę wybrać aktywną specyfikację materiałową.';es_ES = 'El BOM está abierto. Por favor, seleccione el BOM activo.';es_CO = 'El BOM está abierto. Por favor, seleccione el BOM activo.';tr = 'Ürün reçetesi açık. Lütfen, aktif bir ürün reçetesi seçin.';it = 'La distinta base è aperta. Selezionare una distinta base attiva.';de = 'Die Stückliste ist geöffnet. Wählen Sie bitte eine aktive Stückliste.'");
		CommonClientServer.MessageToUser(MessageText);
		Return Result;
		
	ElsIf Not NewBOMByDefault.ValidityEndDate = Date(1,1,1)
		And CurrentSessionDate() >= EndOfDay(NewBOMByDefault.ValidityEndDate) Then
		
		MessageText = NStr("en = 'The BOM''s validity period has expired. Select a valid BOM.'; ru = 'Срок действия спецификации истек. Выберите действующую спецификацию.';pl = 'Okres ważności specyfikacji materiałowej upłynął. Wybierz poprawną specyfikację materiałową.';es_ES = 'El período de validez de la lista de materiales ha expirado. Seleccione una lista de materiales válida.';es_CO = 'El período de validez de la lista de materiales ha expirado. Seleccione una lista de materiales válida.';tr = 'Ürün reçetesinin geçerlilik süresi sona erdi. Geçerli bir ürün reçetesi seçin.';it = 'Il periodo di validità della distinta base è scaduto. Selezionare una distinta base valida.';de = 'Die Gültigkeitsdauer der Stückliste ist abgelaufen. Wählen Sie eine gültige Stückliste aus.'");
		CommonClientServer.MessageToUser(MessageText);
		Return Result;
		
	ElsIf ValueIsFilled(NewBOMByDefault.ProductCharacteristic) Then
		
		MessageText = NStr("en = 'The BOM''s variant is filled in. Please select a BOM that does not have a variant.'; ru = 'Заполнен вариант спецификации. Выберите спецификацию, в которой отсутствуют варианты.';pl = 'Wariant specyfikacji materiałowej jest wypełniony. Wybierz specyfikację materiałową, która nie ma wariantu.';es_ES = 'La variante de la lista de materiales está rellenada. Por favor, seleccione la lista de materiales sin variante.';es_CO = 'La variante de la lista de materiales está rellenada. Por favor, seleccione la lista de materiales sin variante.';tr = 'Ürün reçetesi varyantı dolduruldu. Lütfen, varyantı olmayan bir ürün reçetesi seçin.';it = 'La variante della distinta base è compilata. Selezionare una distinta base che non contiene una variante.';de = 'Die Stücklistenvariante ist ausgefüllt. Wählen Sie bitte eine Stückliste, die keine Variante hat.'");
		CommonClientServer.MessageToUser(MessageText);
		Return Result;
		
	EndIf;
	
	ProductObject 				= ProductOwner.GetObject();
	ProductObject.Specification	= NewBOMByDefault;
	
	Try
		
		ProductObject.Write();
		Result = True;
		
	Except
		
		MessageText = NStr("en = 'Cannot change the default BOM. Close all windows and try again.'; ru = 'Изменение спецификации по умолчанию не доступно. Закройте все окна и повторите попытку.';pl = 'Nie można zmienić domyślnej specyfikacji materiałowej. Zamknij wszystkie okna i spróbuj ponownie.';es_ES = 'No se puede cambiar la lista de materiales por defecto. Cierre todas las ventanas e inténtelo de nuevo.';es_CO = 'No se puede cambiar la lista de materiales por defecto. Cierre todas las ventanas e inténtelo de nuevo.';tr = 'Varsayılan ürün reçetesi değiştirilemiyor. Tüm pencereleri kapatıp tekrar deneyin.';it = 'Impossibile modificare la distinta base predefinita. Chiudere tutte le finestre e riprovare.';de = 'Kann die Standardstückliste nicht ändern. Schließen Sie alle Fenster und versuchen erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
	EndTry;
	
	Return Result;
	
EndFunction

#EndRegion
