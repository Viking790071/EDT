#Region ProgramInterface

// Function exports the changes of products data in the equipment Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting 
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousExportProductsInEquipmentOffline(EquipmentType, DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation, ModifiedOnly = True) Export
	
	Status(NStr("en = 'Exporting goods to offline peripherals...'; ru = 'Выполняется выгрузка товаров в оборудование Offline...';pl = 'Eksportowanie towarów do urządzeń peryferyjnych offline...';es_ES = 'Exportando mercancías para los periféricos offline...';es_CO = 'Exportando mercancías para los periféricos offline...';tr = 'Ürünler çevrimdışı çevre birimlerine aktarılıyor...';it = 'Esportazioni di merci alle apparecchiature Offline ...';de = 'Waren in Offline-Peripheriegeräte exportieren...'"));
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier In DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription = "";
		ClientID = New UUID;
		
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			StructureData = PeripheralsOfflineServerCall.GetDataForPettyCash(DeviceIdentifier, ModifiedOnly);
		Else
			StructureData = PeripheralsOfflineServerCall.GetDataForScales(DeviceIdentifier, ModifiedOnly);
		EndIf;
		
		If StructureData.Data.Count() = 0 Then
			Result = False;
			If StructureData.ExportedRowsWithErrorsCount = 0 Then
				ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(DeviceIdentifier, Undefined, ErrorsDescriptionFull, NStr("en = 'There is no data to export.'; ru = 'Нет данных для выгрузки!';pl = 'Brak danych do eksportu.';es_ES = 'No hay datos para exportar.';es_CO = 'No hay datos para exportar.';tr = 'Dışa aktarılacak veri yok.';it = 'Non ci sono dati per l''esportazione!';de = 'Es gibt keine Daten zum Exportieren.'"));
			Else
				ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(DeviceIdentifier, Undefined, ErrorsDescriptionFull, StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Data is not exported. Errors detected: %1'; ru = 'Данные не выгружены. Обнаружено ошибок: %1';pl = 'Dane nie zostały wyeksportowane. Wystąpił błąd: %1';es_ES = 'Datos no se han exportado. Errores detectados: %1';es_CO = 'Datos no se han exportado. Errores detectados: %1';tr = 'Veri dışa aktarılmıyor. Hatalar tespit edildi: %1';it = 'I dati non vengono scaricati. Errori rilevati: %1';de = 'Daten werden nicht exportiert. Fehler erkannt: %1'"), StructureData.ExportedRowsWithErrorsCount));
			EndIf;
			Continue;
		EndIf;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ImportIntoEquipmentOfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, StructureData",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, StructureData 
			)
		);
		
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			EquipmentManagerClient.StartDataExportToCROffline(
				NotificationsOnCompletion, 
				ClientID,
				DeviceIdentifier,
				StructureData.Data,
				StructureData.PartialExport
			);
		Else
			EquipmentManagerClient.StartDataExportToScalesWithLabelsPrinting(
				NotificationsOnCompletion, 
				ClientID,
				DeviceIdentifier,
				StructureData.Data,
				StructureData.PartialExport
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Function clears the list of products in the equipment Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousClearProductsInEquipmentOffline(EquipmentType, DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation) Export
	
	Status(NStr("en = 'Clearing goods in offline peripherals...'; ru = 'Выполняется очистка товаров в оборудовании Offline...';pl = 'Usuwanie towarów z urządzeń peryferyjnych offline...';es_ES = 'Eliminando mercancías en los periféricos offline...';es_CO = 'Eliminando mercancías en los periféricos offline...';tr = 'Çevrimdışı çevre birimlerindeki mallar temizleniyor...';it = 'Eliminazione di beni nelle periferiche offline...';de = 'Verrechnung von Waren in Offline-Peripheriegeräten...'"));
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier In DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription     = "";
		ClientID = New UUID;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ClearEquipmentBaseOfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation
			)
		);
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			EquipmentManagerClient.StartProductsCleaningInCROffline(
				NotificationsOnCompletion,
				ClientID,
				DeviceIdentifier
			);
		Else
			EquipmentManagerClient.StartClearingProductsInScalesWithLabelsPrinting(
				NotificationsOnCompletion,
				ClientID,
				DeviceIdentifier
			);
		EndIf;
	EndDo;
	
EndProcedure

// Function clears the list of products in the CR Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousImportReportAboutRetailSales(DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation) Export
	
	Status(NStr("en = 'Retail sales reports are being imported from the offline CR...'; ru = 'Выполняется загрузка отчетов о розничных продажах из ККМ Offline...';pl = 'Raporty ze sprzedaży detalicznej są importowane z kasy offline...';es_ES = 'Informes de las ventas al por menor se han importado desde el CR offline...';es_CO = 'Informes de las ventas al por menor se han importado desde el CR offline...';tr = 'Perakende satış raporları çevrimdışı yazar kasadan içe aktarılıyor...';it = 'Report di vendita al dettaglio sono importati dal registratore di cassa offline ...';de = 'Einzelhandelsverkaufsberichte werden aus der Offline-Kassen importiert...'"));
	
	RetailSalesReports = New Array;
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier In DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription  = "";
		ClientID = New UUID;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ImportReportCROfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, RetailSalesReports",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, RetailSalesReports
			)
		);
		EquipmentManagerClient.StartImportRetailSalesReportFromCROffline(
			NotificationsOnCompletion,
			ClientID,
			DeviceIdentifier
		);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

Procedure ImportIntoEquipmentOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Parameters.Completed = Parameters.Completed + 1;
	Else
		Parameters.ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(Parameters.DeviceIdentifier, Parameters.Output_Parameters, Parameters.ErrorsDescriptionFull, Parameters.ErrorDescription);
	EndIf;
	
	PeripheralsOfflineServerCall.OnProductsExportToDevice(Parameters.DeviceIdentifier, Parameters.StructureData, Result);
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousExportProductsInEquipmentOfflineFragment(Parameters);
	EndIf;
	
EndProcedure

Procedure ClearEquipmentBaseOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Parameters.Completed = Parameters.Completed + 1;
	Else
		Parameters.ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(Parameters.DeviceIdentifier, Parameters.Output_Parameters, Parameters.ErrorsDescriptionFull, Parameters.ErrorDescription);
	EndIf;
	
	PeripheralsOfflineServerCall.OnProductsClearingInDevice(Parameters.DeviceIdentifier, Result);
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousClearProductsInEquipmentOfflineFragment(Parameters);
	EndIf;

EndProcedure

Procedure ImportReportCROfflineEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array")
		AND Result.Count() > 0 Then
		ShiftClosure = PeripheralsOfflineServerCall.WhenImportingReportAboutRetailSales(Parameters.DeviceIdentifier, Result);
		If ValueIsFilled(ShiftClosure) Then
			EquipmentManagerClient.StartCheckBoxReportImportedCROffline(
				Parameters.ClientID,
				Parameters.DeviceIdentifier
			);
			Parameters.RetailSalesReports.Add(ShiftClosure);
			Parameters.Completed = Parameters.Completed + 1;
		EndIf;
	EndIf;
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousImportReportAboutRetailSalesFragment(Parameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function GenerateErrorDescriptionForDevice(DeviceIdentifier, Output_Parameters, ErrorsDescriptionFull, ErrorDescription)
	
	Return ErrorsDescriptionFull
	      + Chars.LF
	      + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error description for the %1 device: %2'; ru = 'Описание ошибок для устройства %1: %2';pl = 'Opis błędów dla urządzenia %1: %2';es_ES = 'Descripción del error para el %1 dispositivo: %2';es_CO = 'Descripción del error para el %1 dispositivo: %2';tr = 'Cihazın hata %2 açıklaması:%1';it = 'Descrizione errore per il dispositivo %1: %2';de = 'Fehlerbeschreibung für das %1 Gerät: %2'"), DeviceIdentifier, ErrorDescription)
	      + ?(Output_Parameters <> Undefined, Chars.LF + Output_Parameters[1], "");
	
EndFunction

Procedure AsynchronousExportProductsInEquipmentOfflineFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en = 'The goods have been successfully exported.'; ru = 'Товары успешно выгружены!';pl = 'Towary zostały pomyślnie wyeksportowane.';es_ES = 'Las mercancías se han exportado con éxito.';es_CO = 'Las mercancías se han exportado con éxito.';tr = 'Mallar başarıyla dışa aktarıldı.';it = 'Le merci sono state esportate con successo.';de = 'Die Waren wurden erfolgreich exportiert.'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The goods have been successfully exported for %1 devices from %2.'; ru = 'Товары успешно выгружены для %1 устройств из %2.';pl = 'Towary zostały pomyślnie wyeksportowane dla %1 urządzeń z %2.';es_ES = 'Las mercancías se han exportado con éxito a los %1 dispositivos desde %2.';es_CO = 'Las mercancías se han exportado con éxito a los %1 dispositivos desde %2.';tr = 'Mallar, %1 cihazlar için başarılı bir şekilde dışa aktarıldı %2.';it = 'Le merci sono state esportate con successo per %1 dispositivi da %2.';de = 'Die Waren wurden erfolgreich für %1 Geräte aus exportiert %2.'"), Parameters.Completed, Parameters.NeedToPerform) + Parameters.ErrorsDescriptionFull;
		Else
			MessageText = NStr("en = 'Cannot export the goods:'; ru = 'Выгрузить товары не удалось:';pl = 'Nie można wyeksportować towarów:';es_ES = 'No se puede exportar las mercancías:';es_CO = 'No se puede exportar las mercancías:';tr = 'Mallar dışa aktarılamıyor:';it = 'Non è possibile esportare la merce:';de = 'Die Ware kann nicht exportiert werden:'") + Parameters.ErrorsDescriptionFull;
		EndIf;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en = 'Select a device for which the goods should be exported.'; ru = 'Необходимо выбрать устройство, для которого требуется выгрузить товары.';pl = 'Wybierz urządzenie, do którego towary mają zostać wyeksportowane.';es_ES = 'Seleccionar un dispositivo para el cual las mercancías tienen que exportarse.';es_CO = 'Seleccionar un dispositivo para el cual las mercancías tienen que exportarse.';tr = 'Ürünlerin dışa aktarılması gereken bir cihaz seçin.';it = 'E'' necessario selezionare il dispositivo per il quale è richiesta l''esportazione prodotti.';de = 'Wählen Sie ein Gerät aus, für das die Waren exportiert werden sollen.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

Procedure AsynchronousClearProductsInEquipmentOfflineFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en = 'Goods are successfully cleared.'; ru = 'Товары успешно очищены!';pl = 'Towary zostały pomyślnie oczyszczone.';es_ES = 'Mercancías se han eliminado con éxito.';es_CO = 'Mercancías se han eliminado con éxito.';tr = 'Mallar başarıyla temizlendi.';it = 'Le merci sono state cancellate con successo.';de = 'Waren werden erfolgreich gelöscht.'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Goods are successfully cleared for %1 devices out of %2. %3'; ru = 'Товары успешно очищены для %1 устройств из %2. %3';pl = 'Towary zostały pomyślnie oczyszczone dla %1 urządzeń z %2. %3';es_ES = 'Mercancías se han eliminado con éxito para los %1 dispositivos de %2. %3';es_CO = 'Mercancías se han eliminado con éxito para los %1 dispositivos de %2. %3';tr = 'Ürünler, %1 cihazlarından %2 cihazları için başarıyla temizlendi. %3';it = 'Le merci sono state cancellate con successo per i dispositivi %1 di %2. %3';de = 'Waren werden erfolgreich für %1 Geräte aus %2 gelöscht. %3'"), Parameters.Completed, Parameters.NeedToPerform, Parameters.ErrorsDescriptionFull);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot clear the goods: %1'; ru = 'Очистить товары не удалось: %1';pl = 'Nie można oczyścić towarów: %1';es_ES = 'No se puede eliminar las mercancías: %1';es_CO = 'No se puede eliminar las mercancías: %1';tr = 'Mallar temizlenemiyor: %1';it = 'Non è possibile cancellare la merce: %1';de = 'Kann die Ware nicht löschen: %1'"), Parameters.ErrorsDescriptionFull);
		EndIf;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en = 'Select a device for which the goods should be cleared.'; ru = 'Необходимо выбрать устройство, для которого требуется очистить товары.';pl = 'Wybierz urządzenie, dla którego towary powinny zostać oczyszczone.';es_ES = 'Seleccionar un dispositivo para el cual las mercancías tienen que eliminarse.';es_CO = 'Seleccionar un dispositivo para el cual las mercancías tienen que eliminarse.';tr = 'Ürünlerin temizlenmesi gereken bir cihaz seçin.';it = 'E'' necessario selezionare il dispositivo per il quale è necessario per eliminare i prodotti.';de = 'Wählen Sie ein Gerät aus, für das die Waren gelöscht werden sollen.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

Procedure AsynchronousImportReportAboutRetailSalesFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en = 'The retail sales reports have been successfully imported.'; ru = 'Отчеты о розничных продажах успешно загружены!';pl = 'Raporty ze sprzedaży detalicznej zostały pomyślnie zaimportowane.';es_ES = 'Los informes de las ventas al por menor se han importado con éxito.';es_CO = 'Los informes de las ventas al por menor se han importado con éxito.';tr = 'Perakende satış raporları başarıyla alındı.';it = 'I report di vendita al dettaglio sono stati importati con successo.';de = 'Die Einzelhandelsverkaufsberichte wurden erfolgreich importiert.'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Retail sales reports have been successfully imported for %1 devices from %2.'; ru = 'Успешно загружены отчеты о розничных продажах для %1 устройств из %2.';pl = 'Raporty ze sprzedaży detalicznej zostały pomyślnie zaimportowane dla %1 urządzeń z %2.';es_ES = 'Informes de las ventas al por menor se han importado con éxito para %1 dispositivos desde %2.';es_CO = 'Informes de las ventas al por menor se han importado con éxito para %1 dispositivos desde %2.';tr = 'Perakende satış raporları %1 cihazlarından %2 cihazları için başarıyla içe aktarıldı.';it = 'Report di vendita al dettaglio sono stati importati con successo da %1 dispositivi da %2.';de = 'Einzelhandelsverkaufsberichte wurden erfolgreich für %1 Geräte aus %2 importiert.'"), Parameters.Completed, Parameters.NeedToPerform) + Parameters.ErrorsDescriptionFull;
		Else
			MessageText = NStr("en = 'Cannot import retail sales reports:'; ru = 'Отчеты о розничных продажах загрузить не удалось:';pl = 'Nie można zaimportować raportów ze sprzedaży detalicznej:';es_ES = 'No se puede importar los informes de las ventas al por menor:';es_CO = 'No se puede importar los informes de las ventas al por menor:';tr = 'Perakende satış raporları içe aktarılamıyor:';it = 'Non è possibile importare i report sulle vendite al dettaglio:';de = 'Einzelhandelsumsatzberichte können nicht importiert werden:'") + Parameters.ErrorsDescriptionFull;
		EndIf;
		
		For Each ShiftClosure In Parameters.RetailSalesReports Do
			OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key, PostOnOpen", ShiftClosure, True));
		EndDo;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en = 'Select a device for which the goods should be cleared.'; ru = 'Необходимо выбрать устройство, для которого требуется очистить товары.';pl = 'Wybierz urządzenie, dla którego towary powinny zostać oczyszczone.';es_ES = 'Seleccionar un dispositivo para el cual las mercancías tienen que eliminarse.';es_CO = 'Seleccionar un dispositivo para el cual las mercancías tienen que eliminarse.';tr = 'Ürünlerin temizlenmesi gereken bir cihaz seçin.';it = 'E'' necessario selezionare il dispositivo per il quale è necessario per eliminare i prodotti.';de = 'Wählen Sie ein Gerät aus, für das die Waren gelöscht werden sollen.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

#EndRegion

