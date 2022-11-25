
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
		MessageText = NStr("en = 'Cannot set the main supplier price type. Select a price type whose Counterparty is blank. Then try again.'; ru = 'Не удалось назначить основным типом цен поставщика. Выберите тип цен, для которого не указан контрагент, и повторите попытку.';pl = 'Nie można ustawić głównego rodzaju ceny dostawcy. Wybierz rodzaj ceny, dla którego nie jest określony Kontrahent. Zatem spróbuj ponownie.';es_ES = 'No se puede establecer el tipo de precio del proveedor principal. Seleccione un tipo de precio cuya Contraparte esté vacía. Inténtelo de nuevo.';es_CO = 'No se puede establecer el tipo de precio del proveedor principal. Seleccione un tipo de precio cuya Contraparte esté vacía. Inténtelo de nuevo.';tr = 'Ana tedarikçi fiyatı türü ayarlanamadı. Cari hesabı boş olan bir fiyat türü seçip tekrar deneyin.';it = 'Impossibile impostare il tipo di prezzo fornitore principale. Selezionare un tipo di prezzo la cui Controparte è vuota, poi riprovare.';de = 'Fehler beim Festlegen von Hauptlieferanten-Preistyp. Wählen Sie einen Preistyp mit einem leeren Geschäftspartner aus. Dann versuchen Sie erneut.'");
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