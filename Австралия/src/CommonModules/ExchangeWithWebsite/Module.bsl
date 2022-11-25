#Region Public

Procedure ExecuteExchangeWithWebsite(Parameters, ExchangeResult, InformationTable) Export

	DataProcessor = Parameters.DataProcessor;
	DataProcessor.OnDefineSettings();
	
	WindowsPlatform = WindowsPlatform();
	Parameters.Insert("WindowsPlatform", WindowsPlatform);
	
	ExportCatalog = Parameters.ExportDirectory;
	If Parameters.DataExchangeToWebsite Then
		ExportCatalog = WorkingDirectory();
	Else
		LastChar = Right(ExportCatalog, 1);
		
		If Not LastChar = "\" Then
			ExportCatalog = ExportCatalog + "\";
		EndIf;
		
	EndIf;
	
	SecuritySubdir = "webdata";
	DirectoryOnDisk = ExportCatalog + SecuritySubdir;
	DirectoryOnDisk = PreparePath(WindowsPlatform, DirectoryOnDisk);
	
	ExchangeResult.Insert("ProductsExported", False);
	ExchangeResult.Insert("OrdersImported", False);
	
	Try
		CreateDirectory(DirectoryOnDisk);
	Except
		
		InformationTableRow = InformationTable.Add();
		InformationTableRow.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		InformationTableRow.Description = ExceptionalErrorDescription();
		
		Return;
		
	EndTry;

	Parameters.Insert("DirectoryOnDisk", DirectoryOnDisk);
	
	ImportFile = Parameters.ImportFile;
	ImportFile = PreparePath(WindowsPlatform, ImportFile);
	
	Parameters.Insert("ImportFile", ImportFile);
	Parameters.Insert("FilesSubdir", "import_files");
	Parameters.Insert("CreationDate", CurrentSessionDate());
	
	GetConnectionSettings(Parameters.ConnectionSettings, "");
	
	ResultStructure = New Structure;
	ResultStructure.Insert("ExportedProducts", 0);
	ResultStructure.Insert("ExportedImages", 0);
	ResultStructure.Insert("Error", False);
	ResultStructure.Insert("ErrorDescription", "");
	
	Parameters.Insert("ResultStructure", ResultStructure);
	
	If Parameters.ExportProducts Then 
		CatalogTable = PrepareCatalogTable(Parameters.ExchangeNode);
	Else
		CatalogTable = New ValueTable;
	EndIf;
	ExchangeFileIndex = 0;
	ExchangeFileIndexString = "0";
	
	Success = True;
	
	For Each TableRow In CatalogTable Do
		
		If ExchangeFileIndex > 0 Then
			ExchangeFileIndexString = Format(ExchangeFileIndex, "NG=");
		EndIf;
		
		ExchangeFileIndex = ExchangeFileIndex + 1;
		Parameters.Insert("ExchangeFileIndex", ExchangeFileIndexString);
		
		If Parameters.ExportProducts Then 
			Success = ExportProducts(Parameters, TableRow, InformationTable);
		EndIf;
		
	EndDo;
		
	ExchangeResult.ProductsExported = Success;
	
	OrderExchangeCompleted = ExchageOrders(Parameters, InformationTable);
		
	If Parameters.DataExchangeToWebsite Then
		Try
			DeleteFiles(ExportCatalog);
		Except
			InformationTableRow = InformationTable.Add();
			InformationTableRow.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			InformationTableRow.Description = ExceptionalErrorDescription();
			
			Return;
		EndTry;
	EndIf;
	
EndProcedure

Function TestSiteConnection(ConnectionSettings, MessageText) Export
	
	ConnectionParameters = New Structure("Website, Password, Username, IsWebservice");
	FillPropertyValues(ConnectionParameters, ConnectionSettings);
		
	ErrorDescription = "";
	
	If Not GetConnectionSettings(ConnectionParameters, ErrorDescription) Then
		
		MessageText = NStr("en = 'Couldn''t get the website connection parameters.'; ru = 'Не удалось получить параметры подключения к веб-сайту.';pl = 'Nie udało się pobrać parametrów połączenia do strony internetowej.';es_ES = 'No se pudieron obtener los parámetros de conexión del sitio web.';es_CO = 'No se pudieron obtener los parámetros de conexión del sitio web.';tr = 'Web sitesi bağlantı parametreleri alınamadı.';it = 'Impossibile ottenere i parametri di connessione del sito web.';de = 'Fehler beim Abruf der Verbindungsparameter der Webseite.'")
			+ Chars.LF + ErrorDescription;
		Return False;
		
	EndIf;
	
	Connection = ServerConnection(ConnectionParameters, ErrorDescription);
	If Connection = Undefined Then
		
		MessageText = NStr("en = 'Couldn''t connect to the website. Check the internet connection or website connection settings or try again later.'; ru = 'Не удалось подключиться к веб-сайту. Проверьте подключение к Интернету или настройки подключения к веб-сайту или повторите попытку позже.';pl = 'Nie udało się połączyć do strony internetowej. Sprawdź ustawienia połączenia internetowego lub połączenia ze stroną lub spróbuj ponownie później.';es_ES = 'No se pudo conectar al sitio web. Verifique la conexión a Internet o la configuración de la conexión al sitio web o intente nuevamente más tarde.';es_CO = 'No se pudo conectar al sitio web. Verifique la conexión a Internet o la configuración de la conexión al sitio web o intente nuevamente más tarde.';tr = 'Web sitesine bağlanılamadı. İnternet bağlantısını veya web sitesi bağlantı ayarlarını kontrol edip tekrar deneyin.';it = 'Impossibile connettersi al sito web. Verificare la connessione a internet o le impostazioni di connessioni al sito oppure riprovare più tardi.';de = 'Fehler bei Verbindung mit der Webseite. Überprüfen Sie die Einstellungen der Internetverbindung oder Webseite-Verbindung und versuchen Sie später erneut.'") + Chars.LF + ErrorDescription;
		Return False;
		
	EndIf;
	
	ServerResponse = "";
	
	DataProcessorStorage = Common.ObjectAttributeValue(ConnectionSettings.IntegrationComponent, "DataProcessorStorage");
	DataProcessor = Catalogs.IntegrationComponents.GetDataProcessor(DataProcessorStorage);

	Success = DataProcessor.ExecuteAuthorizationToConnect(Connection,
		ConnectionParameters,
		ServerResponse,
		ErrorDescription);
		
	If Success Then
		MessageText = NStr("en = 'The website connection is established.'; ru = 'Соединение с веб-сайтом установлено.';pl = 'Połączenie ze stroną internetową zostało powiązane.';es_ES = 'Se establece la conexión con el sitio web.';es_CO = 'Se establece la conexión con el sitio web.';tr = 'Web sitesi bağlantısı kuruldu.';it = 'Connessione stabilità con il sito web.';de = 'Die Webseite-Verbindung ist hergestellt.'");
	Else
		MessageText = NStr("en = 'Cannot connect to the website.'; ru = 'Не удалось выполнить подключение к веб-сайту.';pl = 'Nie można połączyć się ze stroną internetową.';es_ES = 'No se puede conectar al sitio web.';es_CO = 'No se puede conectar al sitio web.';tr = 'Web sitesine bağlanılamıyor.';it = 'Impossibile connettersi al sito web.';de = 'Fehler bei Verbindung mit der Webseite.'") + Chars.LF + ErrorDescription;
	EndIf;
	
	Return Success;
	
EndFunction

#EndRegion

#Region Internal

Procedure AddFilterFieldsToSchema(FilterFields, ExportDataSchema) Export
	
	CalculatedFields = ExportDataSchema.CalculatedFields;
	Filter = ExportDataSchema.DefaultSettings.Filter.Items;

	For Each SetFields In FilterFields Do
		
		For Each FieldData Из SetFields.Value Do
			
			If Not CalculatedFields.Find(FieldData.Description) = Undefined Then
				Continue;
			EndIf;
			
			NewField = CalculatedFields.Add();
			
			NewField.Title = FieldData.Synonym;
			NewField.DataPath = FieldData.Description;
			NewField.ValueType = FieldData.ValueType;
			
			If ValueIsFilled(FieldData.Filter) Then
				FillEditingParameters(NewField, FieldData.Filter);
			EndIf;
			
			Filter = ExportDataSchema.DefaultSettings.Filter.Items;
			NewField = Filter.Add(Type("DataCompositionFilterItem"));
			NewField.LeftValue = New DataCompositionField(FieldData.Description);
			NewField.UserSettingID = FieldData.Synonym;
			NewField.Use = False;
			
		EndDo;
	EndDo;

EndProcedure

Function PrepareFilterFields() Export
	
	FilterFields = New ValueTable;
	
	FilterFields.Columns.Add("Description");
	FilterFields.Columns.Add("Synonym");
	FilterFields.Columns.Add("ValueType");
	FilterFields.Columns.Add("Filter");
	
	Return FilterFields;
	
EndFunction

Procedure SetQueryParameter(CompositionParameter, ParameterName, ParameterValue) Export
	
	ParameterItem = CompositionParameter.Add();
	ParameterItem.Name	= ParameterName;
	ParameterItem.Use	= DataCompositionParameterUse.Always;
	ParameterItem.Value	= ParameterValue;
	
EndProcedure

Procedure FillApplicationParameters(AttributesArray, IntegrationComponent) Export
	
	AttributesArray.Add("ExportImages");
	AttributesArray.Add("ExportVariants");
	AttributesArray.Add("ExportBatches");
	AttributesArray.Add("ExportSerialNumbers");
	
	DataProcessor = Common.ObjectAttributeValue(IntegrationComponent, "DataProcessor");
	DataProcessorManager = AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(DataProcessor);
	DataProcessorManager.AddApplicationParameters(AttributesArray);
	
EndProcedure

Function GetAddressStructure(Address) Export
		
	Address = StrReplace(Address, "http://", "");
	Address = StrReplace(Address, "https://", "");
	
	Position = Find(Address, "/");
	
	AddressStructure = New Structure;
	AddressStructure.Insert("Server", Left(Address, Position));
	AddressStructure.Insert("Resource", Right(Address, StrLen(Address) - Position));
	
	Return AddressStructure;	
	
EndFunction

Function TransformDate(DateString) Export
	
	Return Date(StringFunctionsClientServer.ReplaceCharsWithOther("- :", DateString, ""));
	
EndFunction

Function GetPreviouslyImportedOrders(NumberArray) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	SalesOrderAdditionalAttributes.Ref AS Ref,
	|	SalesOrderAdditionalAttributes.Value AS Number
	|FROM
	|	Document.SalesOrder.AdditionalAttributes AS SalesOrderAdditionalAttributes
	|WHERE
	|	SalesOrderAdditionalAttributes.Property = &Property
	|	AND SalesOrderAdditionalAttributes.Value IN(&NumberArray)";
	
	Query.SetParameter("NumberArray", NumberArray);
	Query.SetParameter("Property", ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FindByDescription(NStr("en = 'ID on website'; ru = 'Идентификатор на сайте';pl = 'Identyfikator na stronie internetowej';es_ES = 'ID en el sitio web';es_CO = 'ID en el sitio web';tr = 'Web sitesindeki kimlik numarası';it = 'ID su sito web';de = 'ID auf Webseite'")));
	
	Return Query.Execute().Unload();

EndFunction

Function PreparePath(WindowsPlatform, Path) Export
	
	If WindowsPlatform Then
		SearchSubstring = "/";
		ReplaceSubstring = "\";
	Else
		SearchSubstring = "\";
		ReplaceSubstring = "/";
	EndIf;
	
	Path = StrReplace(Path, SearchSubstring, ReplaceSubstring);
	Return Path;
	
EndFunction

Function ExceptionalErrorDescription(MessageStartText = "", MessageEndText = "") Export
	
	DetailErrorDescription = DetailErrorDescription(ErrorInfo());
	
	MessageText = NStr("en = 'Error occurred:'; ru = 'Возникла ошибка:';pl = 'Zaistniał błąd:';es_ES = 'Ha ocurrido un error:';es_CO = 'Ha ocurrido un error:';tr = 'Hata oluştu:';it = 'Si è verificato un errore:';de = 'Ein Fehler ist aufgetreten:'")
		+ " " + MessageStartText
		+ ?(IsBlankString(MessageEndText), "", Chars.LF + MessageEndText)
		+ ?(IsBlankString(DetailErrorDescription), "", Chars.LF + DetailErrorDescription);
		
	Return MessageText;
	
EndFunction

Function WorkingDirectory(Val SubDir = "", Val UniqueKey = "") Export
	
	DirectoryName = GetTempFileName() + GetPathSeparator();
	CreateDirectory(DirectoryName);
	Return DirectoryName;
	
EndFunction

Procedure AddErrorDescription(Description, Addition) Export

	If IsBlankString(Description) Then
		Description = Addition;
	Else
		Description = Description + Chars.LF + Addition;
	EndIf;

EndProcedure

Function WindowsPlatform() Export
	
	SystemInfo = New SystemInfo;
	WindowsPlatform = SystemInfo.PlatformType = PlatformType.Windows_x86
		Or SystemInfo.PlatformType = PlatformType.Windows_x86_64;
		
	Return WindowsPlatform;
	
EndFunction

Procedure RegisterChangesInNodes(Object, NodeArrayProducts, NodeArrayOrders, Overwrite = False) Export
	
	If NodeArrayProducts.Count() = 0 And NodeArrayOrders.Count() =0 Then
		Return;
	EndIf;
	
	ObjectType = TypeOf(Object);
	
	If ObjectType = Type("AccumulationRegisterRecordSet.Inventory")
		Or ObjectType = Type("InformationRegisterRecordSet.Prices") Then
		
		If Overwrite Then
			
			MetadataObject = Object.Metadata();
			BaseTypeName = Common.BaseTypeNameByMetadataObject(MetadataObject);
			
			If BaseTypeName = "InformationRegisters" Then
				OldRegisterSet = InformationRegisters[MetadataObject.Name].CreateRecordSet();
			ElsIf BaseTypeName = "AccumulationRegisters" Then
				OldRegisterSet = AccumulationRegisters[MetadataObject.Name].CreateRecordSet();
			Else
				
				Return;
				
			EndIf;
			
			For Each FilterValue In Object.Filter Do
				
				If Not FilterValue.Use Then
					Continue;
				EndIf;
				
				FilterRow = OldRegisterSet.Filter.Find(FilterValue.Name);
				FilterRow.Value = FilterValue.Value;
				FilterRow.Use = True;
				
			EndDo;
			
			OldRegisterSet.Read();
			
			For Each Record In OldRegisterSet Do
				
				If TypeOf(Record.Products) = Type("CatalogRef.Products")
					And Common.ObjectAttributeValue(Record.Products, "ProductsType") = Enums.ProductsTypes.InventoryItem Then
					ExchangePlans.RecordChanges(NodeArrayProducts, Record.Products);
				EndIf;
				
			EndDo;
			
		EndIf;
		
		For Each Record In Object Do
			
			If TypeOf(Record.Products) = Type("CatalogRef.Products")
				And Common.ObjectAttributeValue(Record.Products, "ProductsType") = Enums.ProductsTypes.InventoryItem Then
				ExchangePlans.RecordChanges(NodeArrayProducts, Record.Products);
			EndIf;
			
		EndDo;
	
	ElsIf ObjectType = Type("CatalogObject.Products") Then
		
		ExchangePlans.RecordChanges(NodeArrayProducts, Object.Ref);
		
	ElsIf ObjectType = Type("CatalogObject.ProductsAttachedFiles") Then
		
		If Not TypeOf(Object.FileOwner) = Type("CatalogRef.Products") Then
			Return;
		EndIf;
		
		ExchangePlans.RecordChanges(NodeArrayProducts, Object.FileOwner);

		
	ElsIf ObjectType = Type("CatalogObject.ProductsCharacteristics") Then
		
		If TypeOf(Object.Owner) = Type("CatalogRef.Products") Then
			ExchangePlans.RecordChanges(NodeArrayProducts, Object.Owner);
		EndIf;
		
	ElsIf ObjectType = Type("DocumentObject.SalesOrder") Then
		
		For Each ExchangeNode In NodeArrayOrders Do
			
			OrderAtrributesStructureOnWebsite = New Structure;
			OrderAtrributesOnWebsite(Object.Ref, ExchangeNode, OrderAtrributesStructureOnWebsite);
			If ValueIsFilled(OrderAtrributesStructureOnWebsite.OrderNumberOnWebsite) Then
				
				If Object.DeletionMark Then
					ExchangePlans.DeleteChangeRecords(ExchangeNode, Object.Ref);
				Else
					ExchangePlans.RecordChanges(ExchangeNode, Object.Ref);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function ExportProducts(Parameters, CatalogTableRow, InformationTable)
	
	ExchangeFileIndex	= Parameters.ExchangeFileIndex;
	ExecuteExchange 	= True;
	ExportSuccessfully	= True;
	ResultStructure		= Parameters.ResultStructure;
	ExportChangesOnly 	= Parameters.ExportChangesOnly;
	
	DataProcessor = Parameters.DataProcessor;
	
	CompositionSchema = DataProcessor.GetCompositionSchema();
	SettingsComposer = GetCompositionSchemaSettingsComposer(
		CompositionSchema,
		CatalogTableRow.SettingsStorageCatalog);
	
	SetComposerFilter(Parameters, CatalogTableRow, SettingsComposer);
		
	TablesForExport = Undefined;
	ErrorDescription = "";
	
	GetDataForExportProducts(Parameters.ApplicationParameters, SettingsComposer, TablesForExport,
		ErrorDescription, DataProcessor);
	
	If ValueIsFilled(ErrorDescription) Then
		ExchangeWithWebsiteEvents.LogError(ErrorDescription, Parameters.ExchangeNode);
		Return False;
	EndIf;
		
	If TablesForExport.Products.Count() = 0 Then
		Return True;
	EndIf;
			
	ProductsColumn = TablesForExport.Products.UnloadColumn("Products");
	ProductsArray = New Array;
	CommonClientServer.SupplementArray(ProductsArray, ProductsColumn, True);
	
	For Each ArrayItem In ProductsArray Do
		ExchangePlans.RecordChanges(Parameters.ExchangeNode, ArrayItem);
	EndDo;
	
	DeleteProductGroupsRecords(Parameters);
		
	ExchangePlans.SelectChanges(Parameters.ExchangeNode, 0, ProductsArray);
	
	PartIndex = 0;
	MessageNumber = 1;
	OldMessageNumber = Undefined;
	RepeatCount = 0;
	
	InformationTableRow = InformationTable.Add();
	InformationTableRow.ActionOnExchange = Enums.ActionsOnExchange.DataExport;
	InformationTableRow.Description = String(CurrentSessionDate()) + " " + NStr("en = 'Product details export started.'; ru = 'Выгрузка информации о номенклатуре началась.';pl = 'Rozpoczęto eksport szczegółów produktu.';es_ES = 'Se inició la exportación de detalles del producto.';es_CO = 'Se inició la exportación de detalles del producto.';tr = 'Ürün bilgilerinin dışa aktarımı başladı.';it = 'Dettagli articolo esportazione iniziata.';de = 'Export von Produktdetails began.'");
	
	ResultTableForExport =  TablesForExport.Products.CopyColumns();
	ResultTableForExport.Columns.Add("Files");
	ResultTableForExport.Columns.Add("Properties");
	ResultTableForExport.Columns.Add("Prices");
	ResultTableForExport.Columns.Add("Balances");
	
	MessageText = NStr("en = 'Product details export completed.'; ru = 'Выгрузка информации о номенклатуре завершена.';pl = 'Zakończono eksport szczegółów produktu.';es_ES = 'Exportación de detalles del producto completada.';es_CO = 'Exportación de detalles del producto completada.';tr = 'Ürün bilgilerinin dışa aktarımı tamamlandı.';it = 'Dettagli articolo esportazione completata.';de = 'Export von Produktdetails abgeschlossen.'");
	
	While ExecuteExchange Do
		
		ProductsArray = NodeProducts(Parameters.ExchangeNode, Parameters.PartSize, 0);
		
		If ProductsArray.Count() = 0 Then
		
			ProductsTable = NodeMessageNumberProducts(Parameters.ExchangeNode, Parameters.PartSize);
			
			If ProductsTable.Count() = 0 Then
				Break;
			EndIf;
			
			If OldMessageNumber = ProductsTable[0].MessageNo Then
				RepeatCount = RepeatCount + 1;
			EndIf;
			
			If RepeatCount >= Parameters.RepeatCount Then
				
				ExecuteExchange = False;
				If Parameters.RepeatCount > 0 Then
					ExportSuccessfully = False;
				EndIf;
				
				Break;
			EndIf;
			
			ProductsArray = ProductsTable.UnloadColumn("Products");
			OldMessageNumber = ProductsTable[0].MessageNo;
			
		EndIf;
		
		ResultTableForExport.Clear();
		DataProcessor.FillTableForExportProducts(ProductsArray, TablesForExport, ResultTableForExport, SettingsComposer);
		
		If ResultTableForExport.Count() = 0  Then
			For Each ArrayItem In ProductsArray Do
				ExchangePlans.DeleteChangeRecords(Parameters.ExchangeNode, ArrayItem);
			EndDo;
			
			Continue;
		EndIf;
		
		ExportObject = DataProcessor.GetProductsExportObject(Parameters, TablesForExport, ResultTableForExport, CatalogTableRow);
				
		If Parameters.DataExchangeByCommonCatalog Then
		
			WriteOptions = New Structure("ExchangeFileIndex, PartIndex, Name", ExchangeFileIndex, "Products");
			WriteOptions.Insert("MessageText", MessageText);
			
			ExportSuccessfully = DataProcessor.ExportDataToCommonCatalog(Parameters,
				ExportObject,
				WriteOptions,
				TablesForExport,
				ResultStructure,
				InformationTableRow);
		EndIf;
		
		If Parameters.DataExchangeToWebsite Then
			
			WriteOptions = New Structure("ExchangeFileIndex, PartIndex, Name", ExchangeFileIndex, "Products");
			WriteOptions.Insert("MessageText", MessageText);
			
			ExportSuccessfully = DataProcessor.ExportDataToWebsite(Parameters,
				ExportObject,
				WriteOptions,
				TablesForExport,
				ResultStructure,
				InformationTableRow);
		EndIf;
		
		If Parameters.DataExchangeByWebService Then
			ExportSuccessfully = DataProcessor.ExportDataByWebService(Parameters,
			ExportObject,
			TablesForExport,
			ResultStructure,
			InformationTableRow);
		EndIf;
		
		If ExportSuccessfully Then
			
			For Each ArrayItem In ProductsArray Do
				ExchangePlans.DeleteChangeRecords(Parameters.ExchangeNode, ArrayItem);
			EndDo;
			
		Else
			
			If MessageNumber = 1 Then
				ExecuteExchange = False;
				Break;
			EndIf;
						
			If Not OldMessageNumber = Undefined Then
				Continue;
			EndIf;
			
			For Each ArrayItem In ProductsArray Do
				ExchangePlans.RecordChanges(Parameters.ExchangeNode, ArrayItem);
			EndDo;
			ExchangePlans.SelectChanges(Parameters.ExchangeNode, MessageNumber, ProductsArray);
			
		EndIf;
		
		MessageNumber = MessageNumber + 1;
		
	EndDo;
	
	If ExportSuccessfully Then
		Result = Enums.ExchangeExecutionResults.Completed;
	Else
		Result = Enums.ExchangeExecutionResults.Error;
	EndIf;
	CommitCompletionOfExportProducts(InformationTableRow, Result, MessageText);
	
	Return ExportSuccessfully;
	
EndFunction

Function ProxySettings(Settings, Protocol)
	
	Proxy = New InternetProxy;
	
	Proxy.BypassProxyOnLocal = Settings["BypassProxyOnLocal"];
	Proxy.Set(Protocol, Settings["Server"], Settings["Port"], Settings["User"], Settings["Password"]);
	
	Return Proxy;
	
EndFunction

Function GetConnectionSettings(ConnectionSettings, ErrorDescription)
	
	If Not ParseSiteAddress(ConnectionSettings, ErrorDescription) Then
		Return False;
	EndIf;
	
	ProxyServerSetting = New Map;
	GetProxyServerSettings(ProxyServerSetting);

	If ProxyServerSetting <> Undefined
		And ProxyServerSetting["UseProxy"] = False Then
		ProxyServerSetting = Undefined;
	EndIf;
	
	Protocol = ?(ConnectionSettings.SecureConnection, "https", "http");
	Proxy = ?(ProxyServerSetting = Undefined, Undefined, ProxySettings(ProxyServerSetting, Protocol));
	
	ConnectionSettings.Insert("Proxy", Proxy);
	
	Return True;
	
EndFunction

Function ParseSiteAddress(ConnectionSettings, ErrorDescription)
	
	Website = TrimAll(ConnectionSettings.Website); 
	Server = ""; 
	Port = 0;
	ScriptAddress = "";
	SecureConnection = False;
	
	If Not IsBlankString(Website) Then
		
		Website = StrReplace(Website, "\", "/");
		Website = StrReplace(Website, " ", "");
		
		If Lower(Left(Website, 7)) = "http://" Then
			Website = Mid(Website, 8);
		ElsIf Lower(Left(Website, 8)) = "https://" Then
			Website = Mid(Website, 9);
			SecureConnection = True;
		EndIf;
		
		ForwardSlashPosition = StrFind(Website, "/");
		
		If ForwardSlashPosition > 0 Then
			Server = Left(Website, ForwardSlashPosition - 1);
			ScriptAddress = Right(Website, StrLen(Website) - ForwardSlashPosition);
		Else	
			Server = Website;
			ScriptAddress = "";
		EndIf;
		
		ColonPosition = StrFind(Server, ":");
		PortString = "0";
		If ColonPosition > 0 Then
			ServerWithPort = Server;
			Server = Left(ServerWithPort, ColonPosition - 1);
			PortString = Right(ServerWithPort, StrLen(ServerWithPort) - ColonPosition);
		EndIf;
		
		Try
			Port = Number(PortString);
		Except
			
			AddErrorDescription(ErrorDescription,
				ExceptionalErrorDescription(NStr("en = 'Cannot get the port number for the website connection.'; ru = 'Не удалось получить номер порта для подключения к веб-сайту.';pl = 'Nie można uzyskać numeru portu do połączenia ze stroną internetową.';es_ES = 'No se puede obtener el número de puerto para la conexión del sitio web.';es_CO = 'No se puede obtener el número de puerto para la conexión del sitio web.';tr = 'Web sitesi bağlantısı için port numarası alınamıyor.';it = 'Impossibile ottenere il numero di porta per la connessione del sito web.';de = 'Fehler beim Abruf der Port-Nummer für die Webseite-Verbindung.'")
					+ " " + PortString + Chars.LF
					+ NStr("en = 'Check whether the web service address is correct.'; ru = 'Проверьте правильность адреса веб-сервиса.';pl = 'Sprawdź, czy adres usługi webowej jest poprawny.';es_ES = 'Compruebe si la dirección del servicio web es correcta.';es_CO = 'Compruebe si la dirección del servicio web es correcta.';tr = 'Web servisi adresinin doğru olup olmadığını kontrol edin.';it = 'Verificare che l''indirizzo del servizio web sia corretto.';de = 'Überprüfen Sie ob die Adresse des Web-Services korrekt ist.'")));
				
			Return False;
			
		EndTry;
		
		If Port = 0 Then
			Port = ?(SecureConnection, 443, 80);
		EndIf;
		
	EndIf;
	
	ConnectionSettings.Insert("Server", Server); 
	ConnectionSettings.Insert("Port", Port);
	ConnectionSettings.Insert("ScriptAddress", ScriptAddress);
	ConnectionSettings.Insert("SecureConnection", SecureConnection);
	
	Return True;
	
EndFunction

Function ServerConnection(ConnectionParameters, ErrorDescription)
	
	Connection = Undefined;
	
	Try
		
		SecureConnection = Undefined;
		If ConnectionParameters.SecureConnection Then
			SecureConnection = New OpenSSLSecureConnection(Undefined, Undefined);
		EndIf;
		
		Connection = New HTTPConnection(
			ConnectionParameters.Server,
			ConnectionParameters.Port,
			ConnectionParameters.Username,
			ConnectionParameters.Password,
			ConnectionParameters.Proxy,
			180,
			SecureConnection);
	Except
		
		AddErrorDescription(ErrorDescription,
			ExceptionalErrorDescription(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Couldn''t connect to the web server ""%1: %2"". Check the web service address, port number, username, and password.'; ru = 'Не удалось подключиться к веб-серверу ""%1: %2"". Проверьте адрес веб-сервиса, номер порта, логин и пароль.';pl = 'Nie udało się połączyć się z serwerem internetowym ""%1: %2"". Sprawdź adres usługi webowej, numer portu, nazwę użytkownika i hasło.';es_ES = 'No se pudo conectar al servidor web ""%1: %2"". Verifique la dirección del servicio web, el número de puerto, el nombre de usuario y la contraseña.';es_CO = 'No se pudo conectar al servidor web ""%1: %2"". Verifique la dirección del servicio web, el número de puerto, el nombre de usuario y la contraseña.';tr = '""%1: %2"" web sunucusuna bağlanılamadı. Web servisi adresini, port numarasını, kullanıcı adını ve parolayı kontrol edin.';it = 'Impossibile collegarsi al server del web ""%1: %2"". Verificare l''indirizzo del servizio web, numero di porta, nome utente e password.';de = 'Fehler bei Verbindung mit dem Web-Server ""%1: %2"". Überprüfen Sie die Adresse des Web-Services, Port-Nummer, Benutzername und Passwort.'"),
					ConnectionParameters.Server,
					ConnectionParameters.Port)));
		
		Connection = Undefined;
			
	EndTry;
	
	Return Connection;
	
EndFunction

Procedure FillEditingParameters(NewField, Filter)
	
	ChoiceParameters = NewField.EditParameters.Items.Find("ChoiceParameters");
	
	For Each FilterStructure In Filter Do
		
		NewFilter = ChoiceParameters.Value.Add();
		NewFilter.Name = "Filter."+ FilterStructure.FieldName;
		NewFilter.Value = FilterStructure.FilterValue;
		
	EndDo;
	
	ChoiceParameters.Use = True;
	
EndProcedure

Function PrepareCatalogTable(ExchangeNode)
	
	CatalogTable = ExchangeNode.StoredCatalogTable.Get();
	
	For Each CatalogData In CatalogTable Do
		
		ArrayDelete = New Array;
		For Each Group In CatalogData.Groups Do
			If Not ValueIsFilled(Group.Value) Then
				ArrayDelete.Add(Group);
			EndIf;
		EndDo;
		
		For Each ItemDelete In ArrayDelete Do
			CatalogData.Groups.Delete(ItemDelete);
		EndDo;
		
	EndDo;
	
	CatalogTable.Columns.Add("ResultStructure");	
	
	Return CatalogTable;
	
EndFunction

Function NodeProducts(Node, ItemsCount, MessageNo = Undefined)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	Table.Ref AS Products
	|FROM
	|	Catalog.Products.Changes AS Table
	|WHERE
	|	Table.Node = &Node	
	|	AND CASE WHEN &MessageNo = UNDEFINED THEN TRUE
	|		ELSE Table.MessageNo = &MessageNo
	|	END";
	
	Query.Text = StrReplace(Query.Text, "TOP 0", ?(ItemsCount = 0,"", "TOP "+ Format(ItemsCount, "NG="))); 
	
	Query.SetParameter("Node", Node);
	Query.SetParameter("MessageNo", MessageNo);
	Result = Query.Execute();
	
	Return Result.Unload().UnloadColumn("Products");
	
EndFunction

Function NodeMessageNumberProducts(ExchangeNode, ItemsCount)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	Table.Ref AS Products,
	|	Table.MessageNo AS MessageNo
	|FROM
	|	Catalog.Products.Changes AS Table
	|WHERE
	|	Table.Node = &Node";
	
	Query.Text = StrReplace(Query.Text, "TOP 0", ?(ItemsCount = 0,"", "TOP "+ Format(ItemsCount, "NG="))); 
	
	Query.SetParameter("Node", ExchangeNode);
	Result = Query.Execute();
	
	Return Result.Unload();

EndFunction

Function GetCompositionSchemaSettingsComposer(CompositionSchema, ExportSettingsStorage)
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(CompositionSchema)); 
	
	SettingsComposerFromNode = ExportSettingsStorage.Get();
	If ValueIsFilled(SettingsComposerFromNode) Then
		SettingsComposer.LoadSettings(SettingsComposerFromNode);
		SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	Else
		SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	EndIf;
	
	Return SettingsComposer;
	
EndFunction

Procedure SetComposerFilter(Parameters, CatalogTableRow, SettingsComposer)
	
	If Parameters.ExportChangesOnly Then
		ChangeComposerFilter(SettingsComposer,
			Parameters.ApplicationParameters,
			CatalogTableRow.Groups,
			Parameters.StructureOfChanges.Products);
	Else
		ChangeComposerFilter(SettingsComposer,
			Parameters.ApplicationParameters,
			CatalogTableRow.Groups);
	EndIf;

EndProcedure

Procedure ChangeComposerFilter(SettingsComposer,
									ApplicationParameters,
									CatalogGroupList = Undefined,
									ProductsChangesArray = Undefined)
	
	Filter = SettingsComposer.Settings.Filter;
	
	FilterByProducts = "FilterByProducts";
	FilterByChanges = "FilterByChanges";
	
	ArrayDelete = New Array;
	For Each FilterItem In Filter.Items Do
		
		If FilterItem.UserSettingID = FilterByProducts
			Or FilterItem.UserSettingID = FilterByChanges Then
			ArrayDelete.Add(FilterItem);
		EndIf;
		
	EndDo;
	
	For Each DeleteItem In ArrayDelete Do
		Filter.Items.Delete(DeleteItem);
	EndDo;
	
	If CatalogGroupList <> Undefined And CatalogGroupList.Count() > 0 Then
		
		NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewItem.UserSettingID	= FilterByProducts;
		NewItem.LeftValue		= New DataCompositionField("Products");
		NewItem.ComparisonType	= DataCompositionComparisonType.InListByHierarchy;
		NewItem.RightValue		= CatalogGroupList;
		NewItem.Use				= True;
		
	EndIf;
	
	If ProductsChangesArray <> Undefined Then
		
		CatalogGroupList = New ValueList;
		CatalogGroupList.LoadValues(ProductsChangesArray);
		
		NewItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
		NewItem.UserSettingID	= FilterByChanges;
		NewItem.LeftValue		= New DataCompositionField("Products");
		NewItem.ComparisonType	= DataCompositionComparisonType.InListByHierarchy;
		NewItem.RightValue		= CatalogGroupList;
		NewItem.Use				= True;
		
	EndIf;
	
EndProcedure

Procedure DeleteProductGroupsRecords(Val Parameters)
	
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	ProductsChanges.Ref
	|FROM
	|	Catalog.Products.Changes AS ProductsChanges
	|WHERE
	|	ProductsChanges.Node = &Node
	|	AND ProductsChanges.Ref.IsFolder";
	
	Query.SetParameter("Node", Parameters.ExchangeNode);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ExchangePlans.DeleteChangeRecords(Parameters.ExchangeNode, Selection.Ref);
	EndDo;

EndProcedure

Procedure GetDataForExportProducts(ApplicationParameters, Val SettingsComposer, TablesForExport, 
											ErrorDescription, DataProcessorManager)
	
	QueryTexts = New Structure("Products, Properties, Files, Prices, Balances");
	DataProcessorManager.GetQueryTexts(QueryTexts, ApplicationParameters);
	
	Error = False;
	For Each KeyValue In QueryTexts Do
		If Not ValueIsFilled(KeyValue.Value) Then
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The data processor does not support export of the selected details. The data processor file is missing a query text required for such export.'; ru = 'Обработка не поддерживает выгрузку выбранных сведений. В файле обработки отсутствует текст запроса, необходимый для выгрузки.';pl = 'Procesor danych nie obsługuje eksportu wybranych szczegółów. W pliku procesora danych brakuje tekstu zapytania, wymaganego do takiego eksportu.';es_ES = 'El procesador de datos no admite la exportación de los detalles seleccionados. Al archivo del procesador de datos le falta un texto de consulta necesario para dicha exportación.';es_CO = 'El procesador de datos no admite la exportación de los detalles seleccionados. Al archivo del procesador de datos le falta un texto de consulta necesario para dicha exportación.';tr = 'Veri işlemcisi, seçili bilgilerin dışa aktarımını desteklemiyor. Veri işlemcisi dosyasında, bu dışa aktarım için gerekli sorgu metni eksik.';it = 'L''elaborazione dati non supporta l''esportazione dei dettagli selezionati. Al file di elaborazione file manca un testo di query richiesto per questa esportazione.';de = 'Der Datenprozessor unterstützt Export der ausgewählten Details nicht. Die Datei des Datenprozessors enthält keinen für diesen Export benötigten Text der Abfrage.'"),
				KeyValue.Key);
			ErrorDescription = ErrorDescription + ErrorText;
			Error = True;
			
		EndIf;
	EndDo;
	
	If Error Then
		Return;
	EndIf;
	
	DataSourceFields = New Structure;
	FillDataSourceFields(DataSourceFields, DataProcessorManager);
	
	TableProducts = SchemaExecutionResult(SettingsComposer, QueryTexts.Products,
		DataSourceFields.Products, ApplicationParameters, DataProcessorManager);
	TableProducts.Indexes.Add("Products");
	
	TableVariants = Undefined;
	If QueryTexts.Property("Variants") And ApplicationParameters.ExportVariants Then
		TableVariants = SchemaExecutionResult(SettingsComposer, QueryTexts.Variants,
			DataSourceFields.Variants, ApplicationParameters, DataProcessorManager);
		TableVariants.Indexes.Add("Products");
	EndIf;
	
	TableFiles = SchemaExecutionResult(SettingsComposer, QueryTexts.Files, DataSourceFields.Files, ApplicationParameters,
		DataProcessorManager);
	TableFiles.Indexes.Add("Products");
	
	TableProperties = SchemaExecutionResult(SettingsComposer, QueryTexts.Properties,
		DataSourceFields.Properties, ApplicationParameters, DataProcessorManager);
	TableProperties.Indexes.Add("Products");
	
	TablePrices = SchemaExecutionResult(SettingsComposer, QueryTexts.Prices,
		DataSourceFields.Prices, ApplicationParameters, DataProcessorManager);
	TablePrices.Indexes.Add("Products");
	
	TableBalances = SchemaExecutionResult(SettingsComposer, QueryTexts.Balances,
		DataSourceFields.Balances, ApplicationParameters, DataProcessorManager);
	TableBalances.Indexes.Add("Products");
	
	TablesForExport = New Structure;
	TablesForExport.Insert("Products",		TableProducts);
	TablesForExport.Insert("Variants",		TableVariants);
	TablesForExport.Insert("Files",			TableFiles);
	TablesForExport.Insert("Properties",	TableProperties);
	TablesForExport.Insert("Prices",		TablePrices);
	TablesForExport.Insert("Balances",		TableBalances);
	
EndProcedure

Function SchemaExecutionResult(Val SettingsComposer, QueryText, DataSetFields, ApplicationParameters,
		DataProcessorManager)
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add(); 
	DataSource.Name				= "DataSource";
	DataSource.DataSourceType	= "Local";

	DataSetQuery = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSetQuery.AutoFillAvailableFields	= True;
	DataSetQuery.Query						= QueryText;
	DataSetQuery.Name						= "DataSet";
	DataSetQuery.DataSource					= "DataSource";
		
	CompositionParameters = DataCompositionSchema.Parameters;
	
	DataProcessorManager.SetQueryParameters(ApplicationParameters,CompositionParameters);
	
	SettingsSource = New DataCompositionAvailableSettingsSource(DataCompositionSchema);
	
	NewSettingsComposer = New DataCompositionSettingsComposer;
	NewSettingsComposer.Initialize(SettingsSource);
	
	Settings = New ValueStorage(SettingsComposer.GetSettings());
	NewSettingsComposer.LoadSettings(Settings.Get());
	
	DataProcessorManager.SettingsComposerAfterLoadingSettings(NewSettingsComposer);
	
	DeleteFieldsOfOtherDataSets(DataSetFields, NewSettingsComposer.Settings);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, NewSettingsComposer.Settings,,,
		Type("DataCompositionValueCollectionTemplateGenerator"), False);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate,,,);
		
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	
	ResultTable = New ValueTable;
	OutputProcessor.SetObject(ResultTable);
	
	SetPrivilegedMode(True);
	OutputProcessor.Output(CompositionProcessor);
	SetPrivilegedMode(False);
	
	CreateMissingDataTableColumns(SettingsComposer.Settings, ResultTable);
	
	FillDataSetFieldTypes(DataSetFields, ResultTable);
	
	Return ResultTable;
	
EndFunction

Procedure FillDataSetFieldTypes(Val DataSetFields, Val ResultTable)
	
	Var TableColumn, DataSetFieldsRow;
	
	For Each DataSetFieldsRow In DataSetFields Do
		If Not ValueIsFilled(DataSetFieldsRow.FieldValueType) Then
			TableColumn = ResultTable.Columns.Find(DataSetFieldsRow.FieldName);
			If TableColumn <> Undefined Then
				DataSetFieldsRow.FieldValueType = TableColumn.ValueType 
			EndIf;
		EndIf;
	EndDo;

EndProcedure

Procedure CreateMissingDataTableColumns(ComposerSettings, DataTable)
	
	SelectedFields = ComposerSettings.SelectionAvailableFields.Items;
	For Each ComposerField In SelectedFields Do
		
		ColumnName = String(ComposerField.Field);
		
		If Not DataTable.Columns.Find(ColumnName) = Undefined Then
			Continue;
		EndIf;
		
		FieldValueType = ComposerField.ValueType;
		DataTable.Columns.Add(ColumnName, FieldValueType);
		
	EndDo;
	
EndProcedure

Procedure DeleteFieldsOfOtherDataSets(DataSetFields, SettingComposer)
	
	ComposerFields = SettingComposer.Selection.Items;
	Counter = 0;
	
	While Counter < ComposerFields.Count() Do
		
		ComposerField = ComposerFields[Counter];
		If DataSetFields.Find(Upper(ComposerField.Field),"FieldName") = Undefined Then
			ComposerFields.Delete(ComposerField);
		Else
			Counter = Counter +1;
		EndIf;
		
	EndDo;

	DeleteFieldsOfOtherDataSetsRecursively(DataSetFields, SettingComposer.Filter.Items);
	
EndProcedure

Procedure DeleteFieldsOfOtherDataSetsRecursively(DataSetFields, FilterFields)
	
	Counter = 0;
	While Counter < FilterFields.Count() Do
		
		FilterField = FilterFields[Counter];
		
		If TypeOf(FilterField) = Type("DataCompositionFilterItemGroup") Then
			DeleteFieldsOfOtherDataSetsRecursively(DataSetFields, FilterField.Items);
			Counter = Counter + 1;
		Else
			FilterName = FilterField.LeftValue;
		
			PointPosition = StrFind(FilterName, ".");
			If PointPosition > 0 Then
				DimensionName = Left(FilterName, PointPosition -1);
			Else
				DimensionName = FilterName;
			EndIf;
			
			If DataSetFields.Find(Upper(DimensionName),"FieldName") = Undefined Then
				FilterFields.Delete(FilterField);
			Else
				Counter = Counter + 1;
			EndIf;
		EndIf;
		
	EndDo;

EndProcedure

Procedure FillDataSourceFields(StructureWithDataSourceFields, DataProcessorManager, AddFieldsFilter = True)
	
	FilterFields = New Map;
	
	CompositionSchema = DataProcessorManager.GetTemplate("ExportProductsSchema");
	DataProcessorManager.FillFilterFields(FilterFields);
		
	DataSet = CompositionSchema.DataSets.DataSet1.Items;
	For Each DataItem In DataSet Do
	
		SetFields = DataSetFieldsTable();
		For Each SetField In DataItem.Fields Do
			
			NewRow = SetFields.Add();
			NewRow.FieldName = Upper(SetField.Field);
			NewRow.FieldValueType = SetField.ValueType;
			
		EndDo;
		
		If AddFieldsFilter Then
			DataSetName = DataItem.Name;
			CalculatedFields = FilterFields.Get(DataSetName);
			If Not CalculatedFields = Undefined Then
				
				For Each FieldData In CalculatedFields Do
					NewRow = SetFields.Add();
					NewRow.FieldName = Upper(FieldData.Description);
					NewRow.FieldValueType = FieldData.ValueType;
				EndDo;
				
			EndIf;
		EndIf;
		
		StructureWithDataSourceFields.Insert(DataItem.Name, SetFields);
	EndDo;

EndProcedure

Function DataSetFieldsTable()
	
	FieldsTable = New ValueTable;
	FieldsTable.Columns.Add("FieldName");
	FieldsTable.Columns.Add("FieldValueType");
	
	Return FieldsTable;
	
EndFunction
	
Procedure CommitCompletionOfExportProducts(InformationTableRow, Result, CompletionText)
	
	EndDate = CurrentSessionDate();
	
	InformationTableRow.Description = InformationTableRow.Description + Chars.LF
		+ EndDate + " " + CompletionText;
		
	InformationTableRow.ExchangeExecutionResult = Result;
	InformationTableRow.EndDate = EndDate;
	
EndProcedure

Function GetProxyServerSettings(ProxyServerSetting)
	
#If Client Then
	ProxyServerSetting = StandardSubsystemsClient.ClientRunParameters().ProxyServerSettings;
#Else
	ProxyServerSetting = GetFilesFromInternet.ProxySettingsAtServer();
#EndIf
	
EndFunction

Procedure OrderAtrributesOnWebsite(DocRef, ExchangeNode, DataFromWebsite) Export

	PropertyDescription = NStr("en = 'ID on website'; ru = 'Идентификатор на сайте';pl = 'Identyfikator na stronie internetowej';es_ES = 'ID en el sitio web';es_CO = 'ID en el sitio web';tr = 'Web sitesindeki kimlik numarası';it = 'ID su sito web';de = 'ID auf Webseite'");
	AdditionalAttributesOrderNumber = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FindByDescription(PropertyDescription);
	
	Query = New Query;
	Query.Text = "SELECT
	|	SalesOrderAdditionalAttributes.Value,
	|	SalesOrderAdditionalAttributes.Property
	|FROM
	|	Document.SalesOrder.AdditionalAttributes AS SalesOrderAdditionalAttributes
	|WHERE
	|	SalesOrderAdditionalAttributes.Ref = &SalesOrder
	|	AND (SalesOrderAdditionalAttributes.Property = &OrderNumberProperty)";
	
	Query.SetParameter("OrderNumberProperty", AdditionalAttributesOrderNumber);
	Query.SetParameter("SalesOrder", DocRef);
	
	Result = Query.Execute();
	
	DataFromWebsite = New Structure;
	DataFromWebsite.Insert("OrderNumberOnWebsite", "");
	
	Selection = Result.Select();
	While Selection.Next() Do
		DataFromWebsite.OrderNumberOnWebsite = Selection.Value;
	EndDo;

EndProcedure

Function ExchageOrders(Parameters, InformationTable)
	
	If Not Parameters.ImportOrders Then
		Return True;	
	EndIf;
	
	DataProcessor = Parameters.DataProcessor;
	
	OrdersImported = False;
	OrdersExported = False;
	
	OrdersExported = ExportOrders(Parameters, InformationTable);
	
	If Parameters.DataExchangeByWebService Then
		OrdersImported = DataProcessor.ImportDataByWebService(Parameters, InformationTable);
	EndIf;
	
	If Parameters.DataExchangeByCommonCatalog Then
		OrdersImported = DataProcessor.ImportDataFromFile(Parameters, InformationTable);
	EndIf;
	
	Success = OrdersImported And OrdersExported;
	Return Success;	
	
EndFunction

Function ExportOrders(Parameters, InformationTable)
	
	ErrorDescription	= "";
	DataProcessor		= Parameters.DataProcessor;
	ResultStructure		= Parameters.ResultStructure;
	ExportSuccessfully	= True;
	InformationTableRow = InformationTable.Add();
	
	If ValueIsFilled(ErrorDescription) Then
		ExchangeWithWebsiteEvents.LogError(ErrorDescription, Parameters.ExchangeNode);
		Return False;
	EndIf;
			
	UUID = String(New UUID);
	ErrorDescription = "";
	
	PartIndex			= Parameters.PartSize;
	MessageNumber		= 1;
	OldMessageNumber	= Undefined;
	RepeatCount			= 0;
	
    ExecuteExchange = True;
	While ExecuteExchange Do
		
		OrdersWithNumbers = NodeMessageNumberOrder(Parameters.ExchangeNode, Parameters.PartSize);
		
		If OrdersWithNumbers.Count() = 0 Then
			Break;
		EndIf;
		
		OrdersArray = OrdersWithNumbers.UnloadColumn("Order");
		OldMessageNumber = OrdersWithNumbers[0].MessageNo;
		
		MessageText = NStr("en = 'Orders details export completed.'; ru = 'Выгрузка информации о заказах завершена.';pl = 'Zakończono eksport szczegółów zamówień.';es_ES = 'Exportación de detalles de pedidos completada.';es_CO = 'Exportación de detalles de pedidos completada.';tr = 'Sipariş bilgilerinin dışa aktarımı tamamlandı.';it = 'Dettagli ordini esportazione completata.';de = 'Export von Details von Aufträgen abgeschlossen.'");
		ExportObject = DataProcessor.GetOrdersExportObject(Parameters, OrdersArray);
		
		If Parameters.DataExchangeByCommonCatalog Then
		
			WriteOptions = New Structure("Name, MessageText", "Order", MessageText);
			WriteOptions.Insert("MessageText", MessageText);
			
			ExportSuccessfully = DataProcessor.ExportOrdersToCommonCatalog(Parameters,
				ExportObject,
				WriteOptions,
				ResultStructure,
				InformationTableRow);
				
		EndIf;
		
		If Parameters.DataExchangeToWebsite Then
			
			WriteOptions = New Structure("Name, MessageText", "Order", MessageText);
			WriteOptions.Insert("MessageText", MessageText);
			
			ExportSuccessfully = DataProcessor.ExportOrdersToWebsite(Parameters,
				ExportObject,
				WriteOptions,
				ResultStructure,
				InformationTableRow);
		EndIf;
		
		If Parameters.DataExchangeByWebService Then
			ExportSuccessfully = DataProcessor.ExportOrdersByWebService(Parameters,
			ExportObject,
			ResultStructure,
			InformationTableRow);
		EndIf;
				
		If ExportSuccessfully Then
			
			For Each ArrayItem In OrdersArray Do
				ExchangePlans.DeleteChangeRecords(Parameters.ExchangeNode, ArrayItem);
			EndDo;
			
		Else
			
			If Not OldMessageNumber = Undefined Then
				Continue;
			EndIf;
			
			For Each ArrayItem In OrdersArray Do
				ExchangePlans.RecordChanges(Parameters.ExchangeNode, ArrayItem);
			EndDo;
			
			ExchangePlans.SelectChanges(Parameters.ExchangeNode, MessageNumber, OrdersArray);
			
		EndIf;
		
		MessageNumber = MessageNumber + 1;
		
	EndDo;
	
	Return ExportSuccessfully;
	
EndFunction

Function NodeMessageNumberOrder(Node, ItemsCount)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	Table.Ref AS Order,
	|	Table.MessageNo AS MessageNo
	|FROM
	|	Document.SalesOrder.Changes AS Table
	|WHERE
	|	Table.Node = &Node
	|
	|ORDER BY
	|	Table.MessageNo";	
	
	Query.Text = StrReplace(Query.Text, "TOP 0", ?(ItemsCount = 0,"", "TOP "+ Format(ItemsCount, "NG="))); 
	
	Query.SetParameter("Node", Node);
	Result = Query.Execute();
	
	Return Result.Unload();
	
EndFunction

#EndRegion