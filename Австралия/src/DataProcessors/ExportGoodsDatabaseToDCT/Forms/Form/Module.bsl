
&AtServer
Procedure FillBaseOfGoods()
	
	Query = New Query(
	"SELECT
	|	Reg.Barcode AS Barcode,
	|	PRESENTATION(Reg.Products) AS Products,
	|	PRESENTATION(Reg.Characteristic) AS Characteristic,
	|	PRESENTATION(Reg.Batch) AS Batch
	|FROM
	|	InformationRegister.Barcodes AS Reg
	|
	|ORDER BY
	|	Reg.Barcode");
	
	CurTable = Query.Execute().Unload();
	
	ValueToFormAttribute(CurTable, "ExportingTable");
	
EndProcedure

&AtServer
Function GetProductBaseArray()
	
	CurTable = FormAttributeToValue("ExportingTable");
	
	ArrayExportings = New Array();
	
	For Each TSRow In CurTable Do
		StringStructure = New Structure(
			"Barcode, Products, MeasurementUnit, ProductsCharacteristic, ProductsSeries, Quality, Price, Quantity",
			TSRow.Barcode, TSRow.Products, TSRow.Batch, TSRow.Characteristic, "", "" , "", 0);
		ArrayExportings.Add(StringStructure);
	EndDo;
	
	Return ArrayExportings;
	
EndFunction

&AtClient
Procedure FillExecute()
	
	FillBaseOfGoods();
	
EndProcedure

&AtClient
Procedure ExportExecute()
	
	ErrorDescription = "";
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Getting product base
		DCTTable = GetProductBaseArray();
		NotificationsAtExportVTSD = New NotifyDescription("ExportVTSDEnd", ThisObject);
		EquipmentManagerClient.StartDataExportVTSD(NotificationsAtExportVTSD, UUID, DCTTable);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportVTSDEnd(Result, Parameters) Export
	
	If Result Then
		MessageText = NStr("en = 'The data was successfully uploaded into the shipping documents.'; ru = 'Данные успешно выгружены в ТСД.';pl = 'Dane zostały pomyślnie przesłane do dokumentów przewozowych.';es_ES = 'Los datos se han cargado con éxito a los documentos de envío.';es_CO = 'Los datos se han cargado con éxito a los documentos de envío.';tr = 'Veriler gönderim belgelerine başarıyla yüklendi.';it = 'I dati sono stati correttamente caricati sul documento di trasporto.';de = 'Die Daten wurden erfolgreich in die Versanddokumente hochgeladen.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure
