#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	// First launch
	If CloningRelatedData.Count() = 0 Then
		
		NewString				= CloningRelatedData.Add();
		NewString.Check			= True;
		NewString.RelatedData	= NStr("en = 'Product variants'; ru = 'Варианты номенклатуры';pl = 'Warianty produktu';es_ES = 'Variantes del producto';es_CO = 'Variantes del producto';tr = 'Ürün varyantları';it = 'Varianti articolo';de = 'Produktvarianten'");
		NewString.NameHandler	= "ProductVariants";
		
		NewString				= CloningRelatedData.Add();
		NewString.Check			= True;
		NewString.RelatedData	= NStr("en = 'Bills of materials'; ru = 'Спецификации';pl = 'Specyfikacje materiałowe';es_ES = 'Listas de materiales';es_CO = 'Facturas de los materiales';tr = 'Ürün reçeteleri';it = 'Distinte base';de = 'Stücklisten'");
		NewString.NameHandler	= "BillsOfMaterials";

		NewString				= CloningRelatedData.Add();
		NewString.Check			= True;
		NewString.RelatedData	= NStr("en = 'Additional units'; ru = 'Дополнительные единицы';pl = 'Dodatkowe jednostki miary';es_ES = 'Unidades adicionales';es_CO = 'Unidades adicionales';tr = 'Ek birimler';it = 'Unità aggiuntive';de = 'Weitere Einheiten'");
		NewString.NameHandler	= "AdditionalUOMs";

		NewString				= CloningRelatedData.Add();
		NewString.Check			= True;
		NewString.RelatedData	= NStr("en = 'Product cross-references'; ru = 'Номенклатура поставщиков';pl = 'Powiązane informacje o produkcie';es_ES = 'Producto con referencias cruzadas';es_CO = 'Producto con referencias cruzadas';tr = 'Ürün çapraz referansları';it = 'Riferimenti incrociati articolo';de = 'Produktherstellerartikelnummern'");
		NewString.NameHandler	= "ProductCrossReferences";

		NewString				= CloningRelatedData.Add();
		NewString.Check			= True;
		NewString.RelatedData	= NStr("en = 'Product GL accounts'; ru = 'Счета учета номенклатуры';pl = 'Produkt konta księgi głównej';es_ES = 'Producto de las cuentas del libro mayor';es_CO = 'Producto de las cuentas del libro mayor';tr = 'Ürün muhasebe hesapları';it = 'Conti mastro articolo';de = 'Produkt-Hauptbuch-Konten'");
		NewString.NameHandler	= "ProductGLAccounts";
		
		NewString				= CloningRelatedData.Add();
		NewString.Check			= True;
		NewString.RelatedData	= NStr("en = 'Reorder point settings'; ru = 'Управление запасами';pl = 'Stany mini/maks';es_ES = 'Configuraciones del punto del registrador';es_CO = 'Configuraciones del punto del registrador';tr = 'Yeni sipariş noktası ayarları';it = 'Impostazione punti di riordino';de = 'Einstellungen Nachbestellpunkt'");
		NewString.NameHandler	= "ReorderPointSettings";
		
		NewString				= CloningRelatedData.Add();
		NewString.Check			= True;
		NewString.RelatedData	= NStr("en = 'Standard time'; ru = 'Нормы времени работ';pl = 'Norma czasowa';es_ES = 'Tiempo estándar';es_CO = 'Tiempo estándar';tr = 'Standart süre';it = 'Tempo standard';de = 'Standardzeit'");
		NewString.NameHandler	= "StandardTime";
		
		NewString				= CloningRelatedData.Add();
		NewString.Check			= True;
		NewString.RelatedData	= NStr("en = 'Substitute goods'; ru = 'Аналоги номенклатуры';pl = 'Zamienniki';es_ES = 'Reemplazar mercancías';es_CO = 'Reemplazar mercancías';tr = 'Muadil ürünler';it = 'Articoli analoghi';de = 'Ersatzwaren'");
		NewString.NameHandler	= "SubstituteGoods";

	EndIf;
	
	//Title
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Create copy of %1'; ru = 'Создать копию %1';pl = 'Utwórz kopię %1';es_ES = 'Cree una copia de %1';es_CO = 'Cree una copia de %1';tr = '%1 kopyasını yarat';it = 'Creare copia di %1';de = 'Kopie von %1 erstellen'"),
		TrimAll(Parameters.Product));
	
	DontShow = NOT GetUserSettingsUseForm();
	
	If DontShow Then
		CloneProductWithRelatedData();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	
	SettingValue = NOT DontShow;
	DriveServer.SetUserSetting(SettingValue, "UseProductsCloneForm", Users.AuthorizedUser());
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If DontShow Then
		OnCloseAtServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Create(Command)
	
	CloneProductWithRelatedData();
	
EndProcedure

#EndRegion

#Region Private

#Region JobBackground

&AtServer
Function CloneProductWithRelatedDataInBackground()
	
	ProcedureParameters = New Structure("ProductSource, TableRelatedData", Parameters.Product, CloningRelatedData.Unload());
	ProcedureName = "DriveServer.ExecuteCloneProductWithRelatedData";
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Clone product with related data'; ru = 'Клонировать номенклатуру со связанными данными';pl = 'Klonuj produkt za pomocą związanych danych';es_ES = 'Producto clonado con datos relacionados';es_CO = 'Producto clonado con datos relacionados';tr = 'İlgili verilerle ürünü klonla';it = 'Clona articolo con data relativa';de = 'Produkt mit relevanten Daten klonen'");
	
	Return TimeConsumingOperations.ExecuteInBackground(ProcedureName, ProcedureParameters, ExecutionParameters);
	
EndFunction

&AtClient
Procedure CloneProductWithRelatedData()
	
	Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
	Result = CloneProductWithRelatedDataInBackground();
	AfterBackgroundJobStarts(Result);
	
EndProcedure

&AtClient
Procedure AfterBackgroundJobStarts(Result)
	
	JobID				= Result.JobID;
	JobStorageAddress	= Result.ResultAddress;
	
	If Result.Status = "Completed" Then
		AfterJobComplete();
	Else
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterJobComplete()
	
	JobResult = GetFromTempStorage(JobStorageAddress);
	
	If JobResult.Done Then
		ParametersStructure = New Structure;
		ParametersStructure.Insert("Key", JobResult.Product);
		FormProduct = OpenForm("Catalog.Products.ObjectForm",ParametersStructure);
		
		ArrayUnlockItems = New Array;
		ArrayUnlockItems.Add("DescriptionFull");
		ArrayUnlockItems.Add("ProductsType");
		ArrayUnlockItems.Add("MeasurementUnit");
		ArrayUnlockItems.Add("GuaranteePeriod");
		ArrayUnlockItems.Add("WriteOutTheGuaranteeCard");
		ArrayUnlockItems.Add("UseCharacteristics");
		ArrayUnlockItems.Add("UseBatches");
		ArrayUnlockItems.Add("UseSerialNumbers");
		ArrayUnlockItems.Add("ProductsCategory");
		ArrayUnlockItems.Add("PriceGroup");
		ArrayUnlockItems.Add("IsBundle");
		ArrayUnlockItems.Add("BundlePricingStrategy");
		ArrayUnlockItems.Add("BundleDisplayInPrintForms");
		
		ObjectAttributesLockClient.SetAttributeEditEnabling(FormProduct, ArrayUnlockItems);
		ObjectAttributesLockClient.SetFormItemEnabled(FormProduct);
		
		Close();
	Else
		ShowErrorMessageToUser(JobResult.ErrorMessage);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowErrorMessageToUser(Text)
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occured during copy of product with related data.
                  |Contact your partner and provide him following information: %1'; 
                  |ru = 'Во время копирования номенклатуры со связанными данными произошла ошибка.
                  |Обратитесь к вашему партнеру и предоставьте следующую информацию: %1';
                  |pl = 'Błąd wystąpił podczas kopiowania produktu za pomocą związanych danych.
                  |Skontaktuj się ze swoim partnerem i podaj mu następujące informacje: %1';
                  |es_ES = 'Se produjo un error durante la copia del producto con los datos relacionados.
                  |Contacte con su socio y proporciónele la siguiente información: %1';
                  |es_CO = 'Se produjo un error durante la copia del producto con los datos relacionados.
                  |Contacte con su socio y proporciónele la siguiente información: %1';
                  |tr = 'Ürünün ilgili verilerle birlikte kopyalanması sırasında bir hata oluştu. 
                  | İş ortağınıza başvurun ve aşağıdaki bilgileri verin: %1';
                  |it = 'Si è verificato un errore durante la copia dell''articolo con dati correlati. 
                  |Contattare il proprio partner e fornirgli le seguenti informazioni: %1';
                  |de = 'Fehler beim Kopieren des Produktes mit relevanten Daten.
                  |Nehmen Sie Kontakt mit Ihrem Partner und geben ihm die folgenden Informationen: %1'"),
			Text);
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		JobCompleted = JobCompleted(JobID);
	Except
		
		ErrorInfo = BriefErrorDescription(ErrorInfo());
		ShowErrorMessageToUser(ErrorInfo);
		
		Return;
	EndTry;
	
	If JobCompleted Then
		AfterJobComplete();
	Else
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", IdleHandlerParameters.CurrentInterval, True);
	EndIf;

EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

#EndRegion

#Region UserSetting

&AtServer
Function GetUserSettingsUseForm()
	
	UseProductsCloneForm = ChartsOfCharacteristicTypes.UserSettings.UseProductsCloneForm;
	CatalogUser = Users.AuthorizedUser();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	UserSettings.Value AS Value
		|FROM
		|	InformationRegister.UserSettings AS UserSettings
		|WHERE
		|	UserSettings.User = &User
		|	AND UserSettings.Setting = &Setting";
	
	Query.SetParameter("Setting", ChartsOfCharacteristicTypes.UserSettings.UseProductsCloneForm);
	Query.SetParameter("User", CatalogUser);
	
	QueryResult = Query.Execute();
	
	SelectionSetting = QueryResult.Select();
	
	While SelectionSetting.Next() Do
		Return SelectionSetting.Value;
	EndDo;
	
	//Set default value
	
	RecordSet = InformationRegisters.UserSettings.CreateRecordSet();

	RecordSet.Filter.User.Set(CatalogUser);
	RecordSet.Filter.Setting.Set(UseProductsCloneForm);
	
	Record = RecordSet.Add();

	Record.User		= CatalogUser;
	Record.Setting	= UseProductsCloneForm;
	Record.Value	= True;
	
	RecordSet.Write();
	
	Return True;
	
EndFunction

#EndRegion

#EndRegion

