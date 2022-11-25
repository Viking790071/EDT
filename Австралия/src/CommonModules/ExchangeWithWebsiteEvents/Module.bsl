#Region Internal

Procedure ExchangeWithWebsiteOnWriteObject(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
	     Return;
	EndIf;
	
	RegiterChanges(Source);
	
EndProcedure

Procedure ExchangeWithWebsiteBeforeWriteRegister(Source, Cancel, Overwrite) Export
	
	If Source.DataExchange.Load Then
	     Return;
	EndIf;
	
	RegiterChanges(Source, Overwrite);
	
EndProcedure

Procedure ExecuteExchange(Parameters, ResultAddress = "") Export
	
	ExchangeNode = Parameters.ExchangeNode;
	
	Cancel = False;
	ErrorDescription = "";
	
	MessageText = "";
	Properties = Common.ObjectAttributesValues(ExchangeNode, 
		"IntegrationComponent, Company, ExportProducts, ExportVariants, ExportSerialNumbers,
		|ExportBatches, ExportPrices, ExportBalances, ExportImages, ImportCustomers, ImportOrders, DefaultCustomer, Username,
		|ExportDirectory, ImportFile, DataExchangeToWebsite, DataExchangeByWebService, WebService, PartSize, RepeatCount,
		|DataExchangeByCommonCatalog, DefaultCustomer, UsernameWebsite, OverwriteOrders");
	
	If Properties.DataExchangeByWebService
		Or Properties.DataExchangeToWebsite Then
		
		ResourceIsAvailable = False;
		
		CheckConnection(ResourceIsAvailable, ExchangeNode, MessageText);
		If Not ResourceIsAvailable Then
			
			WriteLogEvent(NStr("en = 'Data exchange with website'; ru = 'Обмен данными с веб-сайтом';pl = 'Wymiana danych ze stroną internetową';es_ES = 'Intercambio de datos con el sitio web';es_CO = 'Intercambio de datos con el sitio web';tr = 'Web sitesi ile veri değişimi';it = 'Scambio dati con il sito web';de = 'Datenaustausch mit Webseite'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Warning,
				ExchangeNode.Metadata(),
				ExchangeNode,
				MessageText + " " + NStr("en = 'The exchange has been canceled.'; ru = 'Обмен отменен.';pl = 'Wymiana danych została anulowana.';es_ES = 'El intercambio ha sido cancelado.';es_CO = 'El intercambio ha sido cancelado.';tr = 'Değişim iptal edildi.';it = 'Lo scambio è stato annullato.';de = 'Der Austausch wurde abgebrochen.'"));
			
			CommonClientServer.MessageToUser(MessageText);
			Return;
			
		EndIf;
				
	Else
		
		Cancel = False;
		If Properties.ExportProducts Then
			MessageText = "";

			ExportDirectory = Properties.ExportDirectory;
			CatalogAvailable = False;
			CheckExportDirectoryAvailability(CatalogAvailable, ExportDirectory, MessageText);
			If Not CatalogAvailable Then
				
				WriteLogEvent(NStr("en = 'Exchange with sites'; ru = 'Обмен с сайтами';pl = 'Wymiana ze stronami';es_ES = 'Intercambiar con sitios';es_CO = 'Intercambiar con sitios';tr = 'Siteler ile değişim';it = 'Scambio con siti';de = 'Austausch mit Seiten'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Warning,
					ExchangeNode.Metadata(),
					ExchangeNode,
					MessageText + " " + NStr("en = 'The exchange has been canceled.'; ru = 'Обмен отменен.';pl = 'Wymiana danych została anulowana.';es_ES = 'El intercambio ha sido cancelado.';es_CO = 'El intercambio ha sido cancelado.';tr = 'Değişim iptal edildi.';it = 'Lo scambio è stato annullato.';de = 'Der Austausch wurde abgebrochen.'"));
				
				CommonClientServer.MessageToUser(MessageText);
				Cancel = True;
				
			EndIf;
		EndIf;
		
		If Properties.ImportOrders
			And Not Properties.DataExchangeByWebService Then
			MessageText = "";

			ImportFile = Properties.ImportFile;
			ImportFileAvailable = True;
			CheckImportFileAvailability(ImportFileAvailable, ImportFile, MessageText);
			If Not ImportFileAvailable Then
				
				WriteLogEvent(NStr("en = 'Exchange with sites'; ru = 'Обмен с сайтами';pl = 'Wymiana ze stronami';es_ES = 'Intercambiar con sitios';es_CO = 'Intercambiar con sitios';tr = 'Siteler ile değişim';it = 'Scambio con siti';de = 'Austausch mit Seiten'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Warning,
					ExchangeNode.Metadata(),
					ExchangeNode,
					MessageText + " " + NStr("en = 'Data exchange has been canceled.'; ru = 'Обмен данными отменен.';pl = 'Wymiana danych została anulowana.';es_ES = 'Intercambiar con sitios.';es_CO = 'Intercambiar con sitios.';tr = 'Veri değişimi iptal edildi.';it = 'Lo scambio dati è stato annullato.';de = 'Der Datenaustausch wurde abgebrochen.'"));
				
				CommonClientServer.MessageToUser(MessageText);
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	InformationTable = InformationRegisters.StatesOfExchangeWithWebsite.CreateRecordSet().Unload();
	InformationTable.Columns.Add("Description", New TypeDescription("String"));
	
	ConnectionSettings = New Structure;
	FillConnectionSettings(ConnectionSettings, ExchangeNode);
	
	DataProcessorStorage = Common.ObjectAttributeValue(Properties.IntegrationComponent, "DataProcessorStorage");
	DataProcessor = Catalogs.IntegrationComponents.GetDataProcessor(DataProcessorStorage);

	ExchangeParameters = New Structure;
	ExchangeParameters.Insert("ExchangeNode",			ExchangeNode);
	ExchangeParameters.Insert("DataProcessor",			DataProcessor);
	ExchangeParameters.Insert("ConnectionSettings",		ConnectionSettings);
	
	ExportChangesOnly = Common.ObjectAttributeValue(ExchangeNode, "ExportChangesOnly");
	ExchangeParameters.Insert("ExportChangesOnly",		ExportChangesOnly);
	
	ExchangeParameters.Insert("PartSize",				Properties.PartSize);
	ExchangeParameters.Insert("RepeatCount",			Properties.RepeatCount);
	
	ExchangeParameters.Insert("ExportProducts",			Properties.ExportProducts);
	ExchangeParameters.Insert("ExportVariants",			Properties.ExportVariants);
	ExchangeParameters.Insert("ExportBatches",			Properties.ExportBatches);
	ExchangeParameters.Insert("ExportSerialNumbers",	Properties.ExportSerialNumbers);
	ExchangeParameters.Insert("ExportPrices",			Properties.ExportPrices);
	ExchangeParameters.Insert("ExportBalances",			Properties.ExportBalances);
	ExchangeParameters.Insert("ExportImages",			Properties.ExportImages);
	
	ExchangeParameters.Insert("ExportDirectory",				Properties.ExportDirectory);
	ExchangeParameters.Insert("DataExchangeByCommonCatalog",	Properties.DataExchangeByCommonCatalog);
	ExchangeParameters.Insert("DataExchangeToWebsite",			Properties.DataExchangeToWebsite);
	ExchangeParameters.Insert("DataExchangeByWebService",		Properties.DataExchangeByWebService);
	ExchangeParameters.Insert("WebService",						Properties.WebService);
	ExchangeParameters.Insert("Username",						Properties.Username);
	ExchangeParameters.Insert("UsernameWebsite",				Properties.UsernameWebsite);
	
	ExchangeParameters.Insert("ImportOrders",		Properties.ImportOrders);
	ExchangeParameters.Insert("Company",			Properties.Company);
	ExchangeParameters.Insert("ImportCustomers",	Properties.ImportCustomers);
	ExchangeParameters.Insert("DefaultCustomer",	Properties.DefaultCustomer);
	ExchangeParameters.Insert("OverwriteOrders",	Properties.OverwriteOrders);
		
	ApplicationParameters = GetApplicationParameters(ExchangeNode, ExchangeParameters);
	
	ExchangeParameters.Insert("ApplicationParameters",	ApplicationParameters);
	ExchangeParameters.Insert("ExchangeStartMode",		Parameters.ExchangeStartMode);
	
	If Properties.ExportBalances
		And ExchangeNode.Warehouses.Count() Then
		ExchangeParameters.Insert("Warehouses", ExchangeNode.Warehouses.UnloadColumn("Warehouse"));
	EndIf;
	
	If Properties.ExportPrices
		And ExchangeNode.PriceTypes.Count() Then
		ExchangeParameters.Insert("PriceTypes", ExchangeNode.PriceTypes.UnloadColumn("PriceType"));
	EndIf;
	
	ImportFile = ExchangeNode.ImportFile;
	ImportFile = ExchangeWithWebsite.PreparePath(ExchangeWithWebsite.WindowsPlatform(), ImportFile);
	
	ExchangeParameters.Insert("ImportFile",		ImportFile);
	ExchangeParameters.Insert("CreationDate",	CurrentSessionDate());
	
	StructureOfChanges = New Structure;
	StructureOfChanges.Insert("Orders", New Array);
	
	If ExportChangesOnly Then
		StructureOfChanges.Insert("Products", New Array);
	EndIf;
	
	GetNodeChanges(StructureOfChanges, ExchangeNode);
	ExchangeParameters.Insert("StructureOfChanges", StructureOfChanges);
	
	ExchangeResult = New Structure;
	ExchangeWithWebsite.ExecuteExchangeWithWebsite(ExchangeParameters, ExchangeResult, InformationTable);
	
	Error = (Not ExchangeResult.ProductsExported) Or (Not ExchangeResult.OrdersImported);
	
	ExecuteActionsOnExchangeCompletion(ExchangeParameters, InformationTable, Error);
	
EndProcedure

Procedure JobExchangeWithWebsite(ExchangeNodeCode) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ExchangeWithWebsite);
	
	ExchangeNode = ExchangePlans.Website.FindByCode(ExchangeNodeCode);
	
	If Not ValueIsFilled(ExchangeNode) Then
		
		WriteLogEvent(NStr("en = 'Data exchange with website'; ru = 'Обмен данными с веб-сайтом';pl = 'Wymiana danych ze stroną internetową';es_ES = 'Intercambio de datos con el sitio web';es_CO = 'Intercambio de datos con el sitio web';tr = 'Web sitesi ile veri değişimi';it = 'Scambio dati con il sito web';de = 'Datenaustausch mit Webseite'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			ExchangeNode.Metadata(),
			ExchangeNode,
			NStr("en = 'Exchange node with code is not found'; ru = 'Узел обмена с кодом не найден';pl = 'Nie znaleziono węzła wymiany z kodem';es_ES = 'No se encuentra el nodo de intercambio con el código';es_CO = 'No se encuentra el nodo de intercambio con el código';tr = 'Kod içeren değişim düğümü bulunamadı';it = 'Non è stato trovato il nodo di scambio con codice';de = 'Exchange-Knoten mit Code ist nicht gefunden'") + " " + ExchangeNodeCode);
		
		Return;
		
	EndIf;
	
	If ExchangeNode.DeletionMark Then
		
		WriteLogEvent(NStr("en = 'Data exchange with website'; ru = 'Обмен данными с веб-сайтом';pl = 'Wymiana danych ze stroną internetową';es_ES = 'Intercambio de datos con el sitio web';es_CO = 'Intercambio de datos con el sitio web';tr = 'Web sitesi ile veri değişimi';it = 'Scambio dati con il sito web';de = 'Datenaustausch mit Webseite'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,
			ExchangeNode.Metadata(),
			ExchangeNode,
			NStr("en = 'The data exchange settings are marked for deletion. Data exchange is canceled.'; ru = 'Настройки обмена данными помечены на удаление. Обмен данными отменен.';pl = 'Ustawienia wymiany danych są zaznaczone do usunięcia. Wymiana danych jest anulowana.';es_ES = 'La configuración de intercambio de datos está marcada para su eliminación. Se cancela el intercambio de datos.';es_CO = 'La configuración de intercambio de datos está marcada para su eliminación. Se cancela el intercambio de datos.';tr = 'Veri değişimi ayarları silinmek üzere işaretlendi. Veri değişimi iptal edildi.';it = 'Le impostazioni di scambio dati sono contrassegnate per l''eliminazione. Lo scambio dati è annullato.';de = 'Die Einstellungen des Datenaustauschs sind zum Löschen markiert. Datenaustausch ist abgebrochen.'"));
		
		Return;
		
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("ExchangeNode", ExchangeNode);
	Parameters.Insert("ExchangeStartMode", NStr("en = 'Background exchange'; ru = 'Фоновый обмен';pl = 'Wymiana w tle';es_ES = 'Intercambio de antecedentes';es_CO = 'Intercambio de antecedentes';tr = 'Arka plan değişimi';it = 'Scambio in background';de = 'Hintergrundaustausch'"));
	
	ExecuteExchange(Parameters);
	
EndProcedure

Procedure LogError(MessageText, ExchangeNode) Export
	
	WriteLogEvent(NStr("en = 'Data exchange with website'; ru = 'Обмен данными с веб-сайтом';pl = 'Wymiana danych ze stroną internetową';es_ES = 'Intercambio de datos con el sitio web';es_CO = 'Intercambio de datos con el sitio web';tr = 'Web sitesi ile veri değişimi';it = 'Scambio dati con il sito web';de = 'Datenaustausch mit Webseite'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Warning,
		ExchangeNode.Metadata(),
		ExchangeNode,
		MessageText + NStr("en = 'The exchange has been canceled.'; ru = 'Обмен отменен.';pl = 'Wymiana danych została anulowana.';es_ES = 'El intercambio ha sido cancelado.';es_CO = 'El intercambio ha sido cancelado.';tr = 'Değişim iptal edildi.';it = 'Lo scambio è stato annullato.';de = 'Der Austausch wurde abgebrochen.'"));
	CommonClientServer.MessageToUser(MessageText);
	
EndProcedure

Procedure SalesOrderImportOnWrite(Source, Cancel, PostingMode) Export
	
	If Source.DataExchange.Load
		Or Not Constants.UseExchangeWithWebsite.Get()
		Or Source.OrderState <> Catalogs.SalesOrderStatuses.Open Then
		Return;
	EndIf;
	
	Property = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FindByDescription(NStr("en = 'ID on website'; ru = 'Идентификатор на сайте';pl = 'Identyfikator na stronie internetowej';es_ES = 'ID en el sitio web';es_CO = 'ID en el sitio web';tr = 'Web sitesindeki kimlik numarası';it = 'ID su sito web';de = 'ID auf Webseite'"));
	FoundRow = Source.AdditionalAttributes.Find(Property, "Property");
	
	If FoundRow = Undefined Then
		Return;
	EndIf;
	
	FoundBusinessProcess = BusinessProcesses.Job.FindByAttribute("Topic", Source.Ref);
	
	If Not ValueIsFilled(FoundBusinessProcess)
		Or FoundBusinessProcess.Completed Then
		
		BusinessProcess = BusinessProcesses.Job.CreateBusinessProcess();
		BusinessProcess.Topic					= Source.Ref;
		BusinessProcess.Performer				= Catalogs.PerformerRoles.Salespersons;
		BusinessProcess.MainAddressingObject	= Source.Company;
		BusinessProcess.DueDate					= Source.ShipmentDate;
		BusinessProcess.Description				= NStr("en = 'Confirm Sales order from website'; ru = 'Подтверждение заказа покупателя с веб-сайта';pl = 'Potwierdź Zamówienie sprzedaży ze strony internetowej';es_ES = 'Confirmar pedido de ventas desde el sitio web';es_CO = 'Confirmar pedido de ventas desde el sitio web';tr = 'Web sitesinden Satış siparişini doğrula';it = 'Confermare Ordine cliente da sito web';de = 'Kundenauftrag aus Webseite bestätigen'");
		BusinessProcess.Date					= CurrentDate();
		BusinessProcess.Author					= Users.AuthorizedUser();
		BusinessProcess.Importance				= Enums.TaskImportanceOptions.Normal;
		BusinessProcess.Write();
		BusinessProcess.Start();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure RegiterChanges(Object, Overwrite = False)
	
	If Not GetFunctionalOption("UseExchangeWithWebsite")
		Or Object.AdditionalProperties.Property("DisableObjectChangeRecordMechanism") Then
		Return;
	EndIf;
	
	ObjectType = TypeOf(Object);
	NodeArrayProducts = ExchangeWithWebsiteCached.NodeArrayForRegistration(True);
	NodeArrayOrders = ExchangeWithWebsiteCached.NodeArrayForRegistration( , True);
	ExchangeWithWebsite.RegisterChangesInNodes(Object, NodeArrayProducts, NodeArrayOrders, Overwrite);

EndProcedure

Procedure CheckConnection(Result, ExchangeNode, MessageText)
	
	ConnectionSettings = New Structure;
	FillConnectionSettings(ConnectionSettings, ExchangeNode);
	
	MessageText = "";
	If ExchangeWithWebsite.TestSiteConnection(ConnectionSettings, MessageText) Then
		Result = True;
	Else
		WriteLogEvent(NStr("en = 'Data exchange with website'; ru = 'Обмен данными с веб-сайтом';pl = 'Wymiana danych ze stroną internetową';es_ES = 'Intercambio de datos con el sitio web';es_CO = 'Intercambio de datos con el sitio web';tr = 'Web sitesi ile veri değişimi';it = 'Scambio dati con il sito web';de = 'Datenaustausch mit Webseite'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Warning,
			ExchangeNode.Metadata(),
			ExchangeNode,
			MessageText + " " + NStr("en = 'The exchange has been canceled.'; ru = 'Обмен отменен.';pl = 'Wymiana danych została anulowana.';es_ES = 'El intercambio ha sido cancelado.';es_CO = 'El intercambio ha sido cancelado.';tr = 'Değişim iptal edildi.';it = 'Lo scambio è stato annullato.';de = 'Der Austausch wurde abgebrochen.'"));
			
		Result = False;
		
	EndIf;

EndProcedure

Procedure FillConnectionSettings(ConnectionSettings, ExchangeNode)
	
	ObjectAttributes = Common.ObjectAttributesValues(ExchangeNode, "WebsiteAddress, WebService, UsernameWebsite, Username,
		|IntegrationComponent, DataExchangeByWebService");
	
	ConnectionSettings.Insert("IntegrationComponent",	ObjectAttributes.IntegrationComponent);
	ConnectionSettings.Insert("IsWebservice",			ObjectAttributes.DataExchangeByWebService);
	
	If ObjectAttributes.DataExchangeByWebService Then
		
		ConnectionSettings.Insert("Username",	ObjectAttributes.Username);
		ConnectionSettings.Insert("Website",	ObjectAttributes.WebService);
		PasswordKey = "Password";
		
	Else
		
		ConnectionSettings.Insert("Username",	ObjectAttributes.UsernameWebsite);
		ConnectionSettings.Insert("Website",	ObjectAttributes.WebsiteAddress);
		PasswordKey = "PasswordWebsite";
		
	EndIf;
	
	SetPrivilegedMode(True);
	PasswordFromStorage = Common.ReadDataFromSecureStorage(ExchangeNode, PasswordKey);
	SetPrivilegedMode(False);
	
	ConnectionSettings.Insert("Password", PasswordFromStorage);

EndProcedure

Function EmptyDirectory(Directory, ErrorDescription)
	
	Try
		DeleteFiles(Directory, "*.*");
	Except
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot clear the data exchange directory at %1.'; ru = 'Не удалось очистить каталог обмена данными в %1.';pl = 'Nie można wyczyścić katalogu wymiany danych w %1.';es_ES = 'No se puede borrar el directorio de intercambio de datos en %1.';es_CO = 'No se puede borrar el directorio de intercambio de datos en %1.';tr = 'Veri değişimi dizini temizlenemiyor: %1.';it = 'Impossibile cancellare la directory di scambio dati in %1.';de = 'Fehler beim Löschen des Verzeichnisses des Datenaustauschs bei %1.'"),
			Directory);
		
		ExceptionalErrorDescription = ExchangeWithWebsite.ExceptionalErrorDescription(ErrorText);
		
		ExchangeWithWebsite.AddErrorDescription(ErrorDescription, ExceptionalErrorDescription);
		Return False;
		
	EndTry;
	
	Return True;
	
EndFunction

Procedure GetNodeChanges(ReturnStructure, ExchangePlanNode)
	
	Query = New Query;
	QueryText =
	"SELECT ALLOWED
	|	SalesOrderChanges.Ref AS Ref,
	|	""Orders"" AS RefType
	|FROM
	|	Document.SalesOrder.Changes AS SalesOrderChanges
	|WHERE
	|	SalesOrderChanges.Node = &Node";
	
	If ReturnStructure.Property("Products") Then 
		QueryText = QueryText + DriveClientServer.GetQueryUnion() + 
		"SELECT
		|	ProductsChanges.Ref,
		|	""Products"" 
		|FROM
		|	Catalog.Products.Changes AS ProductsChanges
		|WHERE
		|	ProductsChanges.Node = &Node";

	EndIf;
	
	Query.Text = QueryText;
	Query.SetParameter("Node", ExchangePlanNode);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ReturnStructure[Selection.RefType].Add(Selection.Ref);
	EndDo;
	
EndProcedure

Procedure ExecuteActionsOnExchangeCompletion(Parameters, InformationTable, Error = False)
	
	InformationTable.FillValues(Parameters.ExchangeNode, "ExchangeSetting");
	
	For Each InformationTableRow In InformationTable Do
		
		LogEvent = GetEventLogMessageKey(Parameters.ExchangeNode,
			InformationTableRow.ActionOnExchange);
		
		If InformationTableRow.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed Then
			LogLevel = EventLogLevel.Information;
		Else
			LogLevel = EventLogLevel.Error;
		EndIf;
		
		If Error Then
			LogLevel = EventLogLevel.Error;
		EndIf;
		
		WriteLogEvent(LogEvent,
			LogLevel,
			Parameters.ExchangeNode.Metadata(),
			Parameters.ExchangeNode,
			Parameters.ExchangeStartMode + Chars.LF + InformationTableRow.Description);
			
	EndDo;

	UploadRows = InformationTable.FindRows(New Structure("ActionOnExchange",
		Enums.ActionsOnExchange.DataExport));
	
	If UploadRows.Count() = 2 Then
		
		If UploadRows[1].ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error Then
			UploadRows[0].ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		EndIf;
		
		InformationTable.Delete(UploadRows[1]);
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	For Each InformationTableRow In InformationTable Do
		
		StatusRecord = InformationRegisters.StatesOfExchangeWithWebsite.CreateRecordManager();
		FillPropertyValues(StatusRecord, InformationTableRow);
		
		StatusRecord.StartDate = Parameters.CreationDate;
		StatusRecord.EndDate = CurrentSessionDate();
		StatusRecord.Write();
		
	EndDo;
	
EndProcedure

Function GetEventLogMessageKey(ExchangePlanNode, ActionsOnExchange)
	
	ExchangePlanName     = ExchangePlanNode.Metadata().Name;
	ExchangePlanNodeCode = TrimAll(Common.ObjectAttributeValue(ExchangePlanNode, "Code"));
	
	MessageKey = NStr("en = 'Data exchange ""%1"". Node ""%2"". Details: %3.'; ru = 'Обмен данными ""%1"". Узел ""%2"". Подробнее: %3.';pl = 'Wymiana danych ""%1"". Węzeł ""%2"". Szczegóły: %3.';es_ES = 'Intercambio de datos ""%1"". Nodo ""%2"". Detalles: %3.';es_CO = 'Intercambio de datos ""%1"". Nodo ""%2"". Detalles: %3.';tr = 'Veri değişimi ""%1"". Düğüm ""%2"". Ayrıntılar: %3.';it = 'Scambio dati ""%1"". Nodo ""%2"". Dettagli: %3.';de = 'Datenaustausch""%1"". Knoten ""%2"". Details: %3.'",
		CommonClientServer.DefaultLanguageCode());
	MessageKey = StringFunctionsClientServer.SubstituteParametersToString(MessageKey,
		 ExchangePlanName,
		 ExchangePlanNodeCode,
		 ActionsOnExchange);		 
	
	Return MessageKey;
	
EndFunction

Procedure CheckImportFileAvailability(FileAvailable, ImportFile, MessageText)
	
	ExchangeFile = New File(ImportFile);
	If Not ExchangeFile.Exist() Then
		
		Try
			TextDocument = New TextDocument;
			TextDocument.InsertLine(1, "Test");
			TextDocument.Write(ImportFile);
			
			DeleteFiles(ImportFile);
			
		Except
			ExceptionalErrorDescription = ExchangeWithWebsite.ExceptionalErrorDescription(
				NStr("en = 'Cannot access the data exchange file:'; ru = 'Нет доступа к файлу обмена данными:';pl = 'Nie można uzyskać dostępu do pliku wymiany danych:';es_ES = 'No se puede acceder al archivo de intercambio de datos:';es_CO = 'No se puede acceder al archivo de intercambio de datos:';tr = 'Veri değişimi dosyasına erişilemiyor:';it = 'Impossibile accedere al file di scambio dati:';de = 'Fehler beim Zugriff zur Datenaustauschdatei:'") + " " + ImportFile);
			ExchangeWithWebsite.AddErrorDescription(MessageText, ExceptionalErrorDescription);
			FileAvailable = False;
		EndTry;
	EndIf;
	
EndProcedure

Procedure CheckExportDirectoryAvailability(DirectoryAvailable, ExportCatalog, MessageText)
	
	DirectoryAvailable = True;
		
	If IsBlankString(ExportCatalog) Then
		ExportCatalog = ExchangeWithWebsite.WorkingDirectory();
	Else
		
		LastChar = Right(ExportCatalog, 1);
		
		If Not LastChar = "\" Then
			ExportCatalog = ExportCatalog + "\";
		EndIf;
		
	EndIf;
	
	ExportDirectorySecuritySubdirectory = "webdata";
	DirectoryOnDisk = ExportCatalog + ExportDirectorySecuritySubdirectory;
	DirectoryOnDisk = ExchangeWithWebsite.PreparePath(ExchangeWithWebsite.WindowsPlatform(), DirectoryOnDisk);
	
	Try
		CreateDirectory(DirectoryOnDisk);
	Except
		
		ErrorDescription = "";
		ErrorTemplate = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot access the data exchange directory at %1.'; ru = 'Нет доступа к каталогу обмена данными в %1.';pl = 'Nie można uzyskać dostępu do katalogu wymiany danych w %1.';es_ES = 'No se puede acceder al directorio de intercambio de datos en %1.';es_CO = 'No se puede acceder al directorio de intercambio de datos en %1.';tr = 'Veri değişimi dizinine erişilemiyor: %1.';it = 'Impossibile accedere alla directory di scambio dati in %1.';de = 'Fehler beim Zugriff zum Verzeichnis des Datenaustauschs bei %1.'"),
			DirectoryOnDisk);
		MessageText = ExchangeWithWebsite.ExceptionalErrorDescription(ErrorDescription, ErrorTemplate);
		DirectoryAvailable = False;
		
		Return;
		
	EndTry;
	
	ErrorDescription = "";
	If Not EmptyDirectory(DirectoryOnDisk, ErrorDescription) Then
		
		MessageText = ErrorDescription;
		DirectoryAvailable = False;
		
		Return;
	
	EndIf;
	
EndProcedure

Function GetApplicationParameters(ExchangeNode, Parameters)
	
	ApplicationParameters  = New Structure;
	AttributeList = "ExportImages, ExportVariants, ExportSerialNumbers, ExportBatches,
		|IntegrationComponent, Company";
	ExchangeNodeAttributes = Common.ObjectAttributesValues(ExchangeNode, AttributeList);

	ApplicationParameters.Insert("ExportImages",		ExchangeNodeAttributes.ExportImages);
	ApplicationParameters.Insert("ExportVariants",		ExchangeNodeAttributes.ExportVariants);
	ApplicationParameters.Insert("ExportBatches",		ExchangeNodeAttributes.ExportBatches);
	ApplicationParameters.Insert("ExportSerialNumbers",	ExchangeNodeAttributes.ExportSerialNumbers);
	ApplicationParameters.Insert("Company",				ExchangeNodeAttributes.Company);
	
	PresentationCurrency = Common.ObjectAttributeValue(ExchangeNodeAttributes.Company, "PresentationCurrency");
	ApplicationParameters.Insert("PresentationCurrency", PresentationCurrency);
	
	ApplicationParameters.Insert("PriceTypes",	ExchangeNode.PriceTypes.UnloadColumn("PriceType"));
	ApplicationParameters.Insert("Warehouses",	ExchangeNode.Warehouses.UnloadColumn("Warehouse"));
	
	Parameters.DataProcessor.AddApplicationParameters(ApplicationParameters);
	
	Return ApplicationParameters;
	
EndFunction

#EndRegion

