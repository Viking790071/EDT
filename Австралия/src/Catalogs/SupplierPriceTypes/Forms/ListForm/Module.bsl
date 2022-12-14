
#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MainSupplierPriceType = DriveReUse.GetValueOfSetting("MainSupplierPriceType");
	List.Parameters.SetParameterValue("MainSupplierPriceType", MainSupplierPriceType);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		Items.FormSetTheMainSupplierPriceType.Enabled = Not CurrentData.IsMain;
		Items.FormClearTheMainSupplierPriceType.Enabled = CurrentData.IsMain;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetTheMainSupplierPriceType(Command)
	
	ChangeTheMainSupplierPriceType();
	
EndProcedure

&AtClient
Procedure ClearTheMainSupplierPriceType(Command)
	
	ChangeTheMainSupplierPriceType(False);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ChangeTheMainSupplierPriceType(Set = True)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined
		Or (Set And CurrentData.IsMain) 
		Or (Not Set And Not CurrentData.IsMain) Then
		
		Return;
		
	EndIf;
	
	If Set Then
		SetTheMainSupplierPriceTypeAtServer(CurrentData.Ref);
	Else	
		ClearTheMainSupplierPriceTypeAtServer();
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	Items.FormSetTheMainSupplierPriceType.Enabled = Not CurrentData.IsMain;
	Items.FormClearTheMainSupplierPriceType.Enabled = CurrentData.IsMain;
	
EndProcedure

&AtServer
Procedure SetTheMainSupplierPriceTypeAtServer(Val NewMainPriceType)
	
	Counterparty = Common.ObjectAttributeValue(NewMainPriceType, "Counterparty");
	If ValueIsFilled(Counterparty) Then
		MessageText = NStr("en = 'Cannot set the main supplier price type. Select a price type whose Counterparty is blank. Then try again.'; ru = '???? ?????????????? ?????????????????? ???????????????? ?????????? ?????? ????????????????????. ???????????????? ?????? ??????, ?????? ???????????????? ???? ???????????? ????????????????????, ?? ?????????????????? ??????????????.';pl = 'Nie mo??na ustawi?? g????wnego rodzaju ceny dostawcy. Wybierz rodzaj ceny, dla kt??rego nie jest okre??lony Kontrahent. Zatem spr??buj ponownie.';es_ES = 'No se puede establecer el tipo de precio del proveedor principal. Seleccione un tipo de precio cuya Contraparte est?? vac??a. Int??ntelo de nuevo.';es_CO = 'No se puede establecer el tipo de precio del proveedor principal. Seleccione un tipo de precio cuya Contraparte est?? vac??a. Int??ntelo de nuevo.';tr = 'Ana tedarik??i fiyat?? t??r?? ayarlanamad??. Cari hesab?? bo?? olan bir fiyat t??r?? se??ip tekrar deneyin.';it = 'Impossibile impostare il tipo di prezzo fornitore principale. Selezionare un tipo di prezzo la cui Controparte ?? vuota, poi riprovare.';de = 'Fehler beim Festlegen von Hauptlieferanten-Preistyp. W??hlen Sie einen Preistyp mit einem leeren Gesch??ftspartner aus. Dann versuchen Sie erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
	EndIf;
	
	DriveServer.SetUserSetting(NewMainPriceType, "MainSupplierPriceType");
	
	MainSupplierPriceType = NewMainPriceType;
	List.Parameters.SetParameterValue("MainSupplierPriceType", MainSupplierPriceType);
	
EndProcedure

&AtServer
Procedure ClearTheMainSupplierPriceTypeAtServer()
	
	MainSupplierPriceType = Catalogs.SupplierPriceTypes.EmptyRef();
	DriveServer.SetUserSetting(MainSupplierPriceType, "MainSupplierPriceType");
	
	List.Parameters.SetParameterValue("MainSupplierPriceType", MainSupplierPriceType);
	
EndProcedure

#EndRegion