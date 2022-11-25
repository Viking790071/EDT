#Region Public

// Returns the name of the common attribute that is a separator of main data.
//
// Returns:
//   String - name of the common attribute that is a separator of main data.
//
Function MainDataSeparator() Export
	
	Return Metadata.CommonAttributes.DataAreaMainData.Name;
	
EndFunction

// Returns the name of the common attribute that is a separator of auxiliary data.
//
// Returns:
//   String - name of the common attribute that is a separator of auxiliary data.
//
Function AuxiliaryDataSeparator() Export
	
	Return Metadata.CommonAttributes.DataAreaAuxiliaryData.Name;
	
EndFunction

// Returns the data separation mode flag (conditional separation).
// 
// 
// Returns False if the configuration does not support data separation mode (does not contain 
// attributes to share).
//
// Returns:
//  Boolean - True if separation is enabled.
//         - False is separation is disabled or not supported.
//
Function DataSeparationEnabled() Export
	
	Return SaaSCached.DataSeparationEnabled();
	
EndFunction

// Returns a flag indicating whether separated data (included in the separators) can be accessed.
// The flag is session-specific, but can change its value if data separation is enabled on the 
// session run. So, check the flag right before addressing the shared data.
// 
// Returns True if the configuration does not support data separation mode (does not contain 
// attributes to share).
//
// Returns:
//   Boolean - True if separation is not supported or disabled or separation is enabled and 
//                    separators are set.
//          - False if separation is enabled and separators are not set.
//
Function SeparatedDataUsageAvailable() Export
	
	If Not DataSeparationEnabled() Then
		Return True;
	EndIf;
	
	Return SessionSeparatorUsage();
	
EndFunction

// Clears all session parameters except associated with common DataArea attribute.
// 
//
Procedure ClearAllSessionParametersExceptSeparators() Export
	
	Common.ClearSessionParameters(, "DataAreaValue,DataAreaUsage");
	
EndProcedure

// Checks whether the data area is locked.
//
// Parameters:
//  DataArea - Number - separator value of the data area whose lock state must be checked.
//   
//
// Returns:
//  Boolean - True if data area is locked, False otherwise.
//
Function DataAreaLocked(Val DataArea) Export
	
	varKey = CreateAuxiliaryDataInformationRegisterRecordKey(
	    InformationRegisters.DataAreas,
	    New Structure(AuxiliaryDataSeparator(), DataArea));
	
	Try
		
		LockDataForEdit(varKey);
		
	Except
		
		Return True;
		
	EndTry;
	
	UnlockDataForEdit(varKey);
	
	If NOT SeparatedDataUsageAvailable() Then
		
		Try
			
			SetSessionSeparation(True, DataArea);
			
		Except
			
			SetSessionSeparation(False);
			Return True;
			
		EndTry;
		
		SetSessionSeparation(False);
		
	EndIf;
	
	Return False;
	
EndFunction

// Prepares the data area for use. Starts the infobase update procedure, if necessary, fills in the 
// demo data, sets a new status in the in the DataArea register.
// 
// Parameters:
//   DataArea - Number - separator of the data area to be prepared for use,
//   ExportFileID - UUID - file ID,
//   Option - String - initial data option.
// 
Procedure PrepareDataAreaForUsage(Val DataArea, Val ExportFileID, 
												 Val Option = Undefined) Export
	
	If NOT Users.IsFullUser(, True) Then
		Raise(NStr("ru = 'Недостаточно прав для выполнения операции'; en = 'Insufficient rights to perform the operation'; pl = 'Nie masz wystarczających uprawnień do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operación';es_CO = 'Insuficientes derechos para realizar la operación';tr = 'İşlem için gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausführen der Operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreaKey = CreateAuxiliaryDataInformationRegisterRecordKey(
		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), DataArea));
	LockDataForEdit(AreaKey);
	
	Try
		RecordManager = GetDataAreaRecordManager(DataArea, Enums.DataAreaStatuses.NewDataArea);
		
		If CurrentRunMode() <> Undefined Then
			
			UsersInternal.AuthenticateCurrentUser();
			
		EndIf;
		
		ErrorMessage = "";
		If Not ValueIsFilled(Option) Then
			
			PreparationResult = PrepareDataAreaForUsageFromExport(DataArea, ExportFileID, 
				ErrorMessage);
			
		Else
			
			PreparationResult = PrepareDataAreaForUsageFromPrototype(DataArea, ExportFileID, 
				Option, ErrorMessage);
				
		EndIf;
		
		ChangeAreaStatusAndInformManager(RecordManager, PreparationResult, ErrorMessage);

	Except
		UnlockDataForEdit(AreaKey);
		Raise;
	EndTry;
	
	UnlockDataForEdit(AreaKey);

EndProcedure

// Copies the data of area data to another data area.
// 
// Parameters:
//   SourceArea - Number - value of data area separator of data source.
//   DestinationArea - Number - value of data area separator of destination data.
// 
Procedure CopyAreaData(Val SourceArea, Val DestinationArea) Export
	
	If NOT Users.IsFullUser(, True) Then
		Raise(NStr("ru = 'Недостаточно прав для выполнения операции'; en = 'Insufficient rights to perform the operation'; pl = 'Nie masz wystarczających uprawnień do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operación';es_CO = 'Insuficientes derechos para realizar la operación';tr = 'İşlem için gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausführen der Operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	SetSessionSeparation(True, SourceArea);
	
	ExportFileName = Undefined;
	
	If Not Common.SubsystemExists("CloudTechnology.SaaS.ExportImportDataAreas") Then
		
		RaiseNoCTLSubsystemException("CloudTechnology.SaaS.ExportImportDataAreas");
		
	EndIf;
	
	ModuleExportImportDataAreas = Common.CommonModule("ExportImportDataAreas");
	
	Try
		ExportFileName = ModuleExportImportDataAreas.ExportCurrentDataAreaToArchive();
	Except
		WriteLogEvent(EventLogEventDataAreaCopying(), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		If ExportFileName <> Undefined Then
			Try
				DeleteFiles(ExportFileName);
			Except
				WriteLogEvent(EventLogEventDataAreaCopying(), 
					EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
			EndTry;
		EndIf;
		Raise;
	EndTry;
	
	SetSessionSeparation(Undefined, DestinationArea);
	
	Try
		ModuleExportImportDataAreas.ImportCurrentDataAreaFromArchive(ExportFileName);
	Except
		WriteLogEvent(EventLogEventDataAreaCopying(), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			DeleteFiles(ExportFileName);
		Except
			WriteLogEvent(EventLogEventDataAreaCopying(), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise;
	EndTry;
	
	Try
		DeleteFiles(ExportFileName);
	Except
		WriteLogEvent(EventLogEventDataAreaCopying(), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Deletes all data from the area except the predefined one. Sets the Deleted status for the data 
//  area. Sends the status change message to the service manager.
//   Once the actions have been performed, the data area become unusable.
//
// If all data must be deleted without changing the data area status and the data area must stay 
//  usable, use the ClearAreaData() procedure instead.
//
// Parameters:
//  DataArea - Number - separator of the data area to be cleared,
//   When the procedure is called, the data separation must already be switched to this area.
//  DeleteUsers - Boolean - flag that shows whether user data must be deleted from the data area.
//    
//
Procedure ClearDataArea(Val DataArea, Val DeleteUsers = True) Export
	
	If NOT Users.IsFullUser(, True) Then
		Raise(NStr("ru = 'Недостаточно прав для выполнения операции'; en = 'Insufficient rights to perform the operation'; pl = 'Nie masz wystarczających uprawnień do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operación';es_CO = 'Insuficientes derechos para realizar la operación';tr = 'İşlem için gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausführen der Operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	AreaKey = CreateAuxiliaryDataInformationRegisterRecordKey(
		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), DataArea));
	LockDataForEdit(AreaKey);
	
	Try
		
		RecordManager = GetDataAreaRecordManager(DataArea, Enums.DataAreaStatuses.ForDeletion);
		
		SaaSOverridable.DataAreaOnDelete(DataArea);
		
		ClearAreaData(DeleteUsers); // Calling for clearing
		
		// Restoring the predefined items.
		DataModel = SaaSCached.GetDataAreaModel();

		For each ModelItem In DataModel Do
			
			FullMetadataObjectName = ModelItem.Key;
			
			If IsFullCatalogName(FullMetadataObjectName)
				OR IsFullChartOfAccountsName(FullMetadataObjectName)
				OR IsFullChartOfCharacteristicTypesName(FullMetadataObjectName)
				OR IsFullChartOfCalculationTypesName(FullMetadataObjectName) Then
				
				MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
				
				If MetadataObject.GetPredefinedNames().Count() > 0 Then
					
					Manager = Common.ObjectManagerByFullName(FullMetadataObjectName);
					Manager.SetPredefinedDataInitialization(False);
					
				EndIf;
				
			EndIf;
			
		EndDo;		

		ChangeAreaStatusAndInformManager(RecordManager, "AreaDeleted", "");
		
	Except
		UnlockDataForEdit(AreaKey);
		Raise;
	EndTry;
	
	UnlockDataForEdit(AreaKey);
	
EndProcedure

// Removes all separated data from the data area (even when the data separation is disabled), except 
//  the predefined one.
//
// Parameters:
//  DeleteUsers - Boolean - flag that shows whether the infobase users must be deleted.
//
Procedure ClearAreaData(Val DeleteUsers) Export
	
	DataModel = SaaSCached.GetDataAreaModel();
	
	ClearingExceptions = New Array();
	ClearingExceptions.Add(Metadata.InformationRegisters.DataAreas.FullName());
	
	For each ModelItem In DataModel Do
		
		FullMetadataObjectName = ModelItem.Key;
		MetadataObjectDetails = ModelItem.Value;
		
		If ClearingExceptions.Find(FullMetadataObjectName) <> Undefined Then
			Continue;
		EndIf;
		
		If IsFullConstantName(FullMetadataObjectName) Then
			
			AreaMetadataObject = Metadata.Constants.Find(MetadataObjectDetails.Name);
			ValueManager = Constants[MetadataObjectDetails.Name].CreateValueManager();
			ValueManager.DataExchange.Load = True;
			ValueManager.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
			ValueManager.Value = AreaMetadataObject.Type.AdjustValue();
			ValueManager.Write();
			
		ElsIf IsFullReferenceTypeObjectName(FullMetadataObjectName) Then
			
			IsExchangePlan = IsFullExchangePlanName(FullMetadataObjectName);
			
			Query = New Query(
			"SELECT
			|	T.Ref AS Ref
			|FROM
			|	" + FullMetadataObjectName + " AS T");
			
			If IsExchangePlan Then
				
				Query.Text = Query.Text + "
				|WHERE
				|	T.Ref <> &ThisNode";
				
				Query.SetParameter("ThisNode", ExchangePlans[MetadataObjectDetails.Name].ThisNode());
				
			EndIf;
			
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			
			While Selection.Next() Do
				
				ObjectToDelete = Selection.Ref.GetObject();
				ObjectToDelete.DataExchange.Load = True;
				ObjectToDelete.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				ObjectToDelete.Delete();
				
			EndDo;
			
			
		ElsIf IsFullRegisterName(FullMetadataObjectName)
				OR IsFullRecalculationName(FullMetadataObjectName) Then
			
			IsAccumulationRegister = IsFullAccumulationRegisterName(FullMetadataObjectName);
			IsAccountingRegister = IsFullAccountingRegisterName(FullMetadataObjectName);
			IsInformationRegister = IsFullInformationRegisterName(FullMetadataObjectName);
			
			Manager = Common.ObjectManagerByFullName(FullMetadataObjectName);
			
			IsIndependentInformationRegister = False;
			
			If IsAccumulationRegister Then
				
				MetadataRegister = Metadata.AccumulationRegisters.Find(MetadataObjectDetails.Name);
				
				If MetadataRegister.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
					AccumulationRegisterManager = Manager;
					If AccumulationRegisterManager.GetMinTotalsPeriod() <> '00010101'
						OR AccumulationRegisterManager.GetMaxTotalsPeriod() <> EndOfMonth('00010101') Then
					
						AccumulationRegisterManager.SetMinAndMaxTotalsPeriods('00010101', '00010101');
						
					EndIf;
					
					If AccumulationRegisterManager.GetPresentTotalsUsing() Then
					
						AccumulationRegisterManager.SetPresentTotalsUsing(False);
						
					EndIf;
					
					If AccumulationRegisterManager.GetTotalsUsing() Then
					
						AccumulationRegisterManager.SetTotalsUsing(False);
						
					EndIf;
					
				EndIf;
				
			ElsIf IsAccountingRegister Then
				AccountingRegisterManager = Manager;

				If AccountingRegisterManager.GetMinTotalsPeriod() <> '00010101'
					OR AccountingRegisterManager.GetTotalsPeriod() <> '00010101' Then
				
					AccountingRegisterManager.SetMinAndMaxTotalsPeriods('00010101', '00010101');
					
				EndIf;
				
				If AccountingRegisterManager.GetPresentTotalsUsing() Then
				
					AccountingRegisterManager.SetPresentTotalsUsing(False);
					
				EndIf;
				
				If AccountingRegisterManager.GetTotalsUsing() Then
				
					AccountingRegisterManager.SetTotalsUsing(False);
					
				EndIf;
				
			ElsIf IsInformationRegister Then
				
				MetadataRegister = Metadata.InformationRegisters.Find(MetadataObjectDetails.Name);
				
				If MetadataRegister.EnableTotalsSliceFirst
					OR MetadataRegister.EnableTotalsSliceLast Then
				
					If Manager.GetTotalsUsing() Then
					
						Manager.SetTotalsUsing(False);
						
					EndIf;
					
				EndIf;
				
				IsIndependentInformationRegister = (MetadataRegister.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent);
				
			EndIf;
			
			If IsIndependentInformationRegister Then
				
				RecordSet = Manager.CreateRecordSet();
				RecordSet.DataExchange.Load = True;
				RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
				RecordSet.Write();
				
			Else
				
				SelectionParameters = SelectionParameters(FullMetadataObjectName);
				FieldNameRecorder = SelectionParameters.FieldNameRecorder;
				
				Query = New Query(
				"SELECT DISTINCT
				|	T.Recorder AS Recorder
				|FROM
				|	" + SelectionParameters.Table + " AS T");
				
				If FieldNameRecorder <> "Recorder" Then
					
					Query.Text = StrReplace(Query.Text, "Recorder", FieldNameRecorder);
					
				EndIf;
				
				QueryResult = Query.Execute();
				Selection = QueryResult.Select();
				
				While Selection.Next() Do
					
					RecordSet = Manager.CreateRecordSet();
					RecordSet.Filter[FieldNameRecorder].Set(Selection[FieldNameRecorder]);
					RecordSet.DataExchange.Load = True;
					RecordSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
					RecordSet.Write();
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Users
	If DeleteUsers Then
		
		FirstAdministrator = Undefined;
		
		For each InfobaseUser In InfoBaseUsers.GetUsers() Do
			
			If FirstAdministrator = Undefined AND Users.IsFullUser(InfobaseUser, True, False) Then
				
				// Postpone administrator deletion, so that at the time of its deletion all other users of the 
				// infobase have already been deleted.
				FirstAdministrator = InfobaseUser;
				
			Else
				
				InfobaseUser.Delete();
				
			EndIf;
			
		EndDo;
		
		If FirstAdministrator <> Undefined Then
			
			FirstAdministrator.Delete();
			
		EndIf;
		
	EndIf;
	
	// Settings
	Storages = New Array;
	Storages.Add(ReportsVariantsStorage);
	Storages.Add(FormDataSettingsStorage);
	Storages.Add(CommonSettingsStorage);
	Storages.Add(ReportsUserSettingsStorage);
	Storages.Add(SystemSettingsStorage);
	
	For each Storage In Storages Do
		
		If TypeOf(Storage) <> Type("StandardSettingsStorageManager") Then
			
			// Settings is deleted when clearing data.
			Continue;
			
		EndIf;
		
		Storage.Delete(Undefined, Undefined, Undefined);
		
	EndDo;
	
EndProcedure

// The procedure of the same name scheduled job.
// Finds all data areas with statuses, required to be processed by the application, and, if 
// necessary, plans a maintenance background job startup.
// 
// 
Procedure DataAreaMaintenance() Export
	
	If NOT DataSeparationEnabled() Then
		Return;
	EndIf;
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.DataAreaMaintenance);
	
	MaxRetryCount = 3;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.DataAreaAuxiliaryData AS DataArea,
	|	DataAreas.Status AS Status,
	|	DataAreas.ExportID AS ExportID,
	|	DataAreas.Variant AS Variant
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.Status IN (VALUE(Enum.DataAreaStatuses.NewDataArea), VALUE(Enum.DataAreaStatuses.ForDeletion))
	|	AND DataAreas.ProcessingError = FALSE
	|
	|ORDER BY
	|	DataArea";
	Result = Query.Execute();
	Selection = Result.Select();
	
	Running = 0;
	
	While Selection.Next() Do
		
		varKey = CreateAuxiliaryDataInformationRegisterRecordKey(
			InformationRegisters.DataAreas,
			New Structure(AuxiliaryDataSeparator(), Selection.DataArea));
		
		Try
			LockDataForEdit(varKey);
		Except
			Continue;
		EndTry;
		
		Manager = InformationRegisters.DataAreas.CreateRecordManager();
		Manager.DataAreaAuxiliaryData = Selection.DataArea;
		Manager.Read();
		
		If Manager.Status = Enums.DataAreaStatuses.NewDataArea Then 
			MethodName = "SaaS.PrepareDataAreaForUsage";
		ElsIf Manager.Status = Enums.DataAreaStatuses.ForDeletion Then 
			MethodName = "SaaS.ClearDataArea";
		Else
			UnlockDataForEdit(varKey);
			Continue;
		EndIf;
		
		If Manager.Repeat < MaxRetryCount Then
		
			JobFilter = New Structure;
			JobFilter.Insert("MethodName", MethodName);
			JobFilter.Insert("Key"     , "1");
			JobFilter.Insert("DataArea", Selection.DataArea);
			Jobs = JobQueue.GetJobs(JobFilter);
			If Jobs.Count() > 0 Then
				UnlockDataForEdit(varKey);
				Continue;
			EndIf;
			
			Manager.Repeat = Manager.Repeat + 1;
			
			ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
			FillPropertyValues(ManagerCopy, Manager);
			Manager = ManagerCopy;
			
			Manager.Write();

			MethodParameters = New Array;
			MethodParameters.Add(Selection.DataArea);
			
			If Selection.Status = Enums.DataAreaStatuses.NewDataArea Then
				
				MethodParameters.Add(Selection.ExportID);
				If ValueIsFilled(Selection.Variant) Then
					MethodParameters.Add(Selection.Variant);
				EndIf;
			EndIf;
			
			JobParameters = New Structure;
			JobParameters.Insert("MethodName"    , MethodName);
			JobParameters.Insert("Parameters"    , MethodParameters);
			JobParameters.Insert("Key"         , "1");
			JobParameters.Insert("DataArea", Selection.DataArea);
			JobParameters.Insert("ExclusiveExecution", True);
			
			JobQueue.AddJob(JobParameters);
			
			UnlockDataForEdit(varKey);
		Else
			
			ChangeAreaStatusAndInformManager(Manager, ?(Manager.Status = Enums.DataAreaStatuses.NewDataArea,
				"FatalError", "DeletionError"), NStr("ru = 'Исчерпано количество попыток обработки области'; en = 'Number of attempts to process the area is up'; pl = 'Ilość prób przetworzenia obszaru została przekroczona';es_ES = 'Número de intentos para procesar el área está superado';es_CO = 'Número de intentos para procesar el área está superado';tr = 'Alanı işlemek için deneme sayısı limitine ulaşıldı.';it = 'Il numero di tentativi di elaborazione dell''area è stato esaurito';de = 'Die Anzahl der Versuche, den Bereich zu bearbeiten, wurde überschritten'"));
			
			UnlockDataForEdit(varKey);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns a web service proxy to synchronize administrative actions in SaaS mode.
// 
// Parameters:
//  UserPassword - String - password for connection.
// 
// Returns:
//   WSProxy - service manager proxy.
// 
Function GetServiceManagerProxy(Val UserPassword = Undefined) Export
	
	ServiceManagerURL = InternalServiceManagerURL();
	If Not ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("ru = 'Не установлены параметры связи с менеджером сервиса.'; en = 'Service manager connection parameters are not specified.'; pl = 'Parametry połączenia z menedżerem usług nie są ustawione.';es_ES = 'Parámetros de la conexión con el gestor de servicio no están establecidos.';es_CO = 'Parámetros de la conexión con el gestor de servicio no están establecidos.';tr = 'Servis yöneticisiyle bağlantı parametreleri ayarlanmamış.';it = 'I parametri di connessione del manager di servizio non sono specificati.';de = 'Die Parameter der Verbindung mit dem Service Manager sind nicht festgelegt.'"));
	EndIf;
	
	ServiceAddress = ServiceManagerURL + "/ws/ManageApplication_1_0_3_1?wsdl";
	
	If UserPassword = Undefined Then
		Username = AuxiliaryServiceManagerUsername();
		UserPassword = AuxiliaryServiceManagerUserPassword();
	Else
		Username = UserName();
	EndIf;
	
	ConnectionParameters = Common.WSProxyConnectionParameters();
	ConnectionParameters.WSDLAddress = ServiceAddress;
	ConnectionParameters.NamespaceURI = "http://www.1c.ru/SaaS/ManageApplication/1.0.3.1";
	ConnectionParameters.ServiceName = "ManageApplication_1_0_3_1";
	ConnectionParameters.UserName = Username;
	ConnectionParameters.Password = UserPassword;
	ConnectionParameters.Timeout = 20;
	Proxy = Common.CreateWSProxy(ConnectionParameters);
	
	Return Proxy;
	
EndFunction

// Sets session separation.
//
// Parameters:
//  Usage - Boolean - flag that shows whether the DataArea separator is used in the session.
//  DataArea - Number - DataArea separator value.
//
Procedure SetSessionSeparation(Val Usage = Undefined, Val DataArea = Undefined) Export
	
	If NOT SessionWithoutSeparators() Then
		Raise(NStr("ru = 'Изменить разделение сеанса возможно только из сеанса запущенного без указания разделителей'; en = 'Changing separation settings is only allowed from sessions started without separation'; pl = 'Możesz zmienić podział sesji tylko z sesji działającej bez określonych separatorów';es_ES = 'Usted puede cambiar la separación de la sesión solo desde la sesión en curso sin los separadores especificados';es_CO = 'Usted puede cambiar la separación de la sesión solo desde la sesión en curso sin los separadores especificados';tr = 'Yalnızca sınırlayıcıları belirtmeden çalışan bir oturumdan bir oturum ayırmayı değiştir';it = 'È possibile modificare la separazione della sessione soltanto dalla sessione avviata senza specifica dei separatori';de = 'Sie können die Sitzungstrennung nur in der Sitzung ändern, in der keine Trennzeichen angegeben sind'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Usage <> Undefined Then
		SessionParameters.DataAreaUsage = Usage;
	EndIf;
	
	If DataArea <> Undefined Then
		SessionParameters.DataAreaValue = DataArea;
	EndIf;
	
	DataAreaOnChange();
	
EndProcedure

// Returns a value of the current data area separator.
// If the value is not set an error is raised.
// 
// Returns:
//   Number - value of the current data area separator.
// 
Function SessionSeparatorValue() Export
	
	If NOT DataSeparationEnabled() Then
		Return 0;
	Else
		If Not SessionSeparatorUsage() Then
			Raise(NStr("ru = 'Не установлено значение разделителя'; en = 'The separator value is not specified.'; pl = 'Nie ustawiono wartości separatora';es_ES = 'Valor del separador no está establecido';es_CO = 'Valor del separador no está establecido';tr = 'Ayırıcı değeri ayarlanmadı';it = 'Il valore di separazione non è specificato.';de = 'Trennzeichenwert ist nicht festgelegt'"));
		EndIf;
		
		// Getting value of the current data area separator.
		Return SessionParameters.DataAreaValue;
	EndIf;
	
EndFunction

// Returns the flag that shows whether DataArea separator is used.
//
// Returns:
//  Boolean - True if separation is used, False otherwise.
//
Function SessionSeparatorUsage() Export
	
	Return SessionParameters.DataAreaUsage;
	
EndFunction

// Adds parameter details to the parameter table by the constant name.
// Returns the added parameter.
//
// Parameters:
//   ParameterTable - ValueTable - infobase parameter details table.
//   ConstantName - String - name of the constant to be added to the infobase parameters.
//
// Returns:
//   ValueTableRow - details of the added parameter.
// 
Function AddConstantToIBParametersTable(Val ParametersTable, Val ConstantName) Export
	
	MetadataConstants = Metadata.Constants[ConstantName];
	
	CurParameterString = ParametersTable.Add();
	CurParameterString.Name = MetadataConstants.Name;
	CurParameterString.Details = MetadataConstants.Presentation();
	CurParameterString.Type = MetadataConstants.Type;
	
	Return CurParameterString;
	
EndFunction

// Returns the infobase parameter table.
//
// Returns:
//     ValueTable - infobase parameters. Contains the following columns:
//         * Name - String - a parameter name.
//         * Details - String - parameter details to be displayed in the user interface.
//         * ReadProhibition - Boolean - flag that shows whether the infobase parameter cannot be read. 
//                                   Can be set, for example, for passwords.
//         * WriteProhibition - Boolean - flag that shows whether the infobase parameter cannot be changed.
//         * Type - TypesDetails - parameter value type. It is allowed to use only primitive types 
//                                 and enumerations that are in the configuration, used to manage this configuration.
//
Function GetIBParametersTable() Export
	
	ParametersTable = GetBlankIBParametersTable();
	
	OnFillIIBParametersTable(ParametersTable);
	
	SaaSOverridable.OnFillIIBParametersTable(ParametersTable);
	
	Return ParametersTable;
	
EndFunction

// Gets the application name, as it has been specified by a subscriber.
//
// Returns:
//   String - application name.
//
Function GetApplicationName() Export
	
	SetPrivilegedMode(True);
	Return Constants.DataAreaPresentation.Get();
	
EndFunction

// Returns the block size in MB to transfer a large file in parts.
//
// Returns:
//   Number - file transfer block size in megabytes.
//
Function GetFileTransferBlockSize() Export
	
	SetPrivilegedMode(True);
	
	FileTransferBlockSize = Constants.FileTransferBlockSize.Get(); // MB
	If Not ValueIsFilled(FileTransferBlockSize) Then
		FileTransferBlockSize = 20;
	EndIf;
	Return FileTransferBlockSize;

EndFunction

// Serializes a structural type object.
//
// Parameters:
//   StructuralTypeValue - Array, Structure, Map - object to serialize.
//
// Returns:
//   String - serialized value of a structural type object.
//
Function WriteStructuralXDTODataObjectToString(Val StructuralTypeValue) Export
	
	XDTODataObject = StructuralObjectToXDTODataObject(StructuralTypeValue);
	
	Return WriteValueToString(XDTODataObject);
	
EndFunction

// Encodes a string value using the Base64 algorithm.
//
// Parameters:
//   String - String - original string to be encoded.
//
// Returns:
//   String - encoded string.
//
Function StringToBase64(Val Row) Export
	
	Storage = New ValueStorage(Row, New Deflation(9));
	
	Return XMLString(Storage);
	
EndFunction

// Decodes Base64 presentation of the string into the original value.
//
// Parameters:
//   StringBase64 - String - original string to be decoded.
//
// Returns:
//   String - decoded string.
//
Function Base64ToString(Val Base64Row) Export
	
	Storage = XMLValue(Type("ValueStorage"), Base64Row);
	
	Return Storage.Get();
	
EndFunction

// Returns the data area time zone.
// Is intended to be called from the sessions where the separation is disabled.
//  In the sessions where the separation is enabled, use GetInfobaseTimeZone() instead.
// 
//
// Parameters:
//  DataArea - Number - separator of the data area whose time zone is retrieved.
//   
//
// Returns:
//  String, Undefined - data area time zone, Undefined if the time zone is not specified.
//   
//
Function GetDataAreaTimeZone(Val DataArea) Export
	
	Manager = Constants.DataAreaTimeZone.CreateValueManager();
	Manager.DataAreaAuxiliaryData = DataArea;
	Manager.Read();
	TimeZone = Manager.Value;
	
	If Not ValueIsFilled(TimeZone) Then
		TimeZone = Undefined;
	EndIf;
	
	Return TimeZone;
	
EndFunction

// Returns the internal Service manager URL.
//
// Returns:
//  String - the internal service manager URL.
//
Function InternalServiceManagerURL() Export
	
	ModuleSaaSCTL = Common.CommonModule("SaaSCTL");
	Return ModuleSaaSCTL.InternalServiceManagerURL();
	
EndFunction

// Returns the auxiliary Service manager user name.
//
// Returns:
//  String - the auxiliary service manager user name.
//
Function AuxiliaryServiceManagerUsername() Export
	
	CTLModuleToCall = Common.CommonModule("SaaSCTL");
	Return CTLModuleToCall.AuxiliaryServiceManagerUsername();
	
EndFunction

// Returns the auxiliary Service manager user password.
//
// Returns:
//  String - auxiliary service manager user password.
//
Function AuxiliaryServiceManagerUserPassword() Export
	
	CTLModuleToCall = Common.CommonModule("SaaSCTL");
	Return CTLModuleToCall.AuxiliaryServiceManagerUserPassword();
	
EndFunction

// Handles web service errors.
// If the passed error info is not empty, writes the error details to the event log and raises an 
// exception with the brief error description.
// 
//
// Parameters:
//   ErrorInformation - ErrorInformation - error information,
//   SubsystemName - String - subsystem name,
//   WebServiceName - String - web service name,
//   OperationName - String - operation name.
//
Procedure HandleWebServiceErrorInfo(Val ErrorInformation, Val SubsystemName = "", Val WebServiceName = "", Val OperationName = "") Export
	
	If ErrorInformation = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(SubsystemName) Then
		SubsystemName = Metadata.Subsystems.StandardSubsystems.Subsystems.SaaS.Name;
	EndIf;
	
	EventName = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '%1.Ошибка вызова операции web-сервиса'; en = '%1.Error calling the web service operation'; pl = '%1.Błąd wywołania operacji usługi webowej';es_ES = '%1.Error de la llamada de la operación del servicio web';es_CO = '%1.Error de la llamada de la operación del servicio web';tr = '%1. Web servis işlem çağrısı hatası';it = '%1.Errore di chiamata di funzione dell''operazione del servizio web';de = '%1.Webservice Operation Aufruffehler'", CommonClientServer.DefaultLanguageCode()),
		SubsystemName);
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Ошибка при вызове операции %1 веб-сервиса %2: %3'; en = 'An error occurred when calling operation %1 of web service %2: %3'; pl = 'Wystąpił błąd podczas wywoływania operacji %1 usługi webowej %2: %3';es_ES = 'Ha ocurrido un error al llamar la operación %1 del servicio web %2: %3';es_CO = 'Ha ocurrido un error al llamar la operación %1 del servicio web %2: %3';tr = '%1Web hizmeti işletimi %2çağrılırken bir hata oluştu:%3';it = 'Si è verificato un errore durante il richiamo dell''operazione %1 di servizio web %2: %3';de = 'Beim Aufruf der Operation %1 des Webservice ist ein Fehler aufgetreten %2: %3'", CommonClientServer.DefaultLanguageCode()),
		OperationName,
		WebServiceName,
		ErrorInformation.DetailErrorDescription);
	
	WriteLogEvent(
		EventName,
		EventLogLevel.Error,
		,
		,
		ErrorText);
		
	Raise ErrorInformation.BriefErrorDescription;
	
EndProcedure

// Returns the user alias to be used in the interface.
//
// Parameters:
//   UserID - UUID - user ID.
//
// Returns:
//   String - infobase user alias to be shown in interface.
//
Function InfobaseUserAlias(Val UserID) Export
	
	Alias = "";
	
	SaaSIntegration.OnDetermineUserAlias(UserID, Alias);
	Return Alias;
	
EndFunction

// Gets the record manager for the DataAreas register in the transaction.
//
// Parameters:
//  DataArea - Number - data area number.
//  Status - Enums.DataAreaStatuses - expected data area status.
//
// Returns:
//  InformationRegisters.DataAreas.RecordManager - data area record manager.
//
Function GetDataAreaRecordManager(Val DataArea, Val Status) Export
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		Item = Lock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataAreaAuxiliaryData", DataArea);
		Item.Mode = DataLockMode.Shared;
		Lock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.Read();
		
		If NOT RecordManager.Selected() Then
			MessageTemplate = NStr("ru = 'Область данных %1 не найдена'; en = '%1 data area is not found'; pl = 'Nie znaleziono obszaru danych %1';es_ES = 'Área de datos %1 no encontrada';es_CO = 'Área de datos %1 no encontrada';tr = 'Veri alanı %1 bulunamadı.';it = 'l''area dati %1 non è stata trovata';de = 'Datenbereich %1 wurde nicht gefunden'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, DataArea);
			Raise(MessageText);
		ElsIf RecordManager.Status <> Status Then
			MessageTemplate = NStr("ru = 'Статус области данных %1 не равен ""%2""'; en = 'Status of data area %1 is not ""%2""'; pl = 'Status obszaru danych %1 różni się od ""%2""';es_ES = 'Estado del área de datos %1 no es ""%2""';es_CO = 'Estado del área de datos %1 no es ""%2""';tr = '%1Veri alanın durumu ""%2"" değil';it = 'Area dati di stato%1 non è uguale ""%2""';de = 'Status des Datenbereichs %1 ist nicht ""%2""'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, DataArea, Status);
			Raise(MessageText);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogEventDataAreaPreparation(), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Return RecordManager;
	
EndFunction

// Imports data into the "standard" area.
// 
// Parameters:
//   DataArea - Number - number of the data area to be filled.
//   ExportFileID - UUID - initial data file ID.
//   Option - String - initial data option.
//   ErrorMessage - String - a returned error details.
//
// Returns:
//  String - "Success" or "FatalError".
//
Function PrepareDataAreaForUsageFromPrototype(Val DataArea, Val ExportFileID, 
												 		  Val Option, ErrorMessage) Export
	
	If Constants.CopyDataAreasFromPrototype.Get() Then
		
		Result = ImportDataAreaFromSuppliedData(DataArea, ExportFileID, Option, ErrorMessage);
		If Result <> "Success" Then
			Return Result;
		EndIf;
		
	Else
		
		Result = "Success";
		
	EndIf;
	
	InfobaseUpdate.UpdateInfobase();
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File operations

// Returns the full name of the file, received from the service manager file storage by the file ID.
//
// Parameters:
//   FileID - UUID - file ID in the service manager file storage.
//
// Returns:
//   String - extracted file full name.
//
Function GetFileFromServiceManagerStorage(Val FileID) Export
	
	FileDetails = Undefined;
	
	ServiceManagerURL = InternalServiceManagerURL();
	
	If NOT ValueIsFilled(ServiceManagerURL) Then
		
		Raise(NStr("ru = 'Не установлены параметры связи с менеджером сервиса.'; en = 'Service manager connection parameters are not specified.'; pl = 'Parametry połączenia z menedżerem usług nie są ustawione.';es_ES = 'Parámetros de la conexión con el gestor de servicio no están establecidos.';es_CO = 'Parámetros de la conexión con el gestor de servicio no están establecidos.';tr = 'Servis yöneticisiyle bağlantı parametreleri ayarlanmamış.';it = 'I parametri di connessione del manager di servizio non sono specificati.';de = 'Die Parameter der Verbindung mit dem Service Manager sind nicht festgelegt.'"));
		
	EndIf;
	
	StorageAccessParameters = New Structure;
	StorageAccessParameters.Insert("URL", ServiceManagerURL);
	StorageAccessParameters.Insert("UserName", AuxiliaryServiceManagerUsername());
	StorageAccessParameters.Insert("Password", AuxiliaryServiceManagerUserPassword());
	
	If Common.SubsystemExists("CloudTechnology.DataTransfer") Then
		
		SupportedVersions = Common.GetInterfaceVersions(StorageAccessParameters, "DataTransfer");
		
		If SupportedVersions.Count() > 0 Then
			
			// In one version of the CTL DataTransfer common module was renamed the DataTransferServer to resolve the name conflict.
			// For compatibility, both module names are supported.
			Try
				
				ModuleDataTransfer = Common.CommonModule("DataTransferServer");
				
			Except
				
				ModuleDataTransfer = Common.CommonModule("DataTransfer");
				
			EndTry;
			
			FileDetails = ModuleDataTransfer.GetFromLogicalStorage(StorageAccessParameters, "files", FileID);
			
		EndIf;
		
	EndIf;
	
	If FileDetails = Undefined Then
		
		FileDetails = GetFileFromStorage(FileID, StorageAccessParameters, True, True);
		
	EndIf;
	
	If FileDetails = Undefined Then
		
		Return Undefined;
		
	EndIf;
	
	FIleProperties = New File(FileDetails.FullName);
	
	If Not FIleProperties.Exist() Then
		
		Return Undefined;
		
	EndIf;
	
	// Service manager sets the Read-only attribute to the source file.
	// Inherited attribute removed before deleting the file.
	FIleProperties.SetReadOnly(False);	
	
	Return FIleProperties.FullName;
	
EndFunction

// Adds a file to the service manager storage.
//
// Parameters:
//   AddressDataFile - String - file address in a temporary storage,
//                   - BinaryData - binary file data,
//                   - File - file.
//   FileName - String - stored file name.
//		
// Returns:
//   UUID - file ID in the storage.
//
Function PutFileInServiceManagerStorage(Val AddressDataFile, Val FileName = "") Export
	
	FileIDInStorage = Undefined;
	
	StorageAccessParameters = New Structure;
	StorageAccessParameters.Insert("URL", InternalServiceManagerURL());
	StorageAccessParameters.Insert("UserName", AuxiliaryServiceManagerUsername());
	StorageAccessParameters.Insert("Password", AuxiliaryServiceManagerUserPassword());
	
	If Common.SubsystemExists("CloudTechnology.DataTransfer") Then
		
		SupportedVersions = Common.GetInterfaceVersions(StorageAccessParameters, "DataTransfer");
		
		If SupportedVersions.Count() > 0 Then
			
			// In one version of the CTL DataTransfer common module was renamed the DataTransferServer to resolve the name conflict.
			// For compatibility, both module names are supported.
			Try
				
				ModuleDataTransfer = Common.CommonModule("DataTransferServer");
				
			Except
				
				ModuleDataTransfer = Common.CommonModule("DataTransfer");
				
			EndTry;
			
			FileIDInStorage = ModuleDataTransfer.SendToLogicalStorage(StorageAccessParameters, "files", AddressDataFile, FileName);
			
		EndIf;
		
	EndIf;
		
	If ValueIsFilled(FileIDInStorage) Then
		
		Return FileIDInStorage;
		
	Else
		
		Return PutFileInStorage(AddressDataFile, StorageAccessParameters, FileName);
		
	EndIf;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for determining types of metadata objects by full metadata object names.
// 

// Reference data types.

// Determines whether the metadata object is one of Document type objects by the full metadata 
//  object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a document.
//
Function IsFullDocumentName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Document", "Document");
	
EndFunction

// Determines whether the metadata object is one of Catalog type objects by the full metadata object 
//  name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a catalog.
//
Function IsFullCatalogName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Catalog", "Catalog");
	
EndFunction

// Determines whether the metadata object is one of Enumeration type objects by the full metadata 
//  object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is an enumeration.
//
Function IsFullEnumerationName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Enum", "Enum");
	
EndFunction

// Determines whether the metadata object is one of Exchange plan type objects by the full metadata 
//  object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is an exchange plan.
//
Function IsFullExchangePlanName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "ExchangePlan", "ExchangePlan");
	
EndFunction

// Determines whether the metadata object is one of Chart of characteristic types type objects by 
//  the full metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a chart of characteristic types.
//
Function IsFullChartOfCharacteristicTypesName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "ChartOfCharacteristicTypes", "ChartOfCharacteristicTypes");
	
EndFunction

// Determines whether the metadata object is one of Business process type objects by the full 
//  metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a business process.
//
Function IsFullBusinessProcessName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "BusinessProcess", "BusinessProcess");
	
EndFunction

// Determines whether the metadata object is one of Task type objects by the full metadata object 
//  name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
// 
// Returns:
//  Boolean - True if the object is a task.
//
Function IsFullTaskName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Task", "Task");
	
EndFunction

// Determines whether the metadata object is one of Chart of accounts type objects by the full 
//  metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a chart of accounts.
//
Function IsFullChartOfAccountsName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "ChartOfAccounts", "ChartOfAccounts");
	
EndFunction

// Determines whether the metadata object is one of Chart of calculation types type objects by the 
//  full metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a chart of calculation types.
//
Function IsFullChartOfCalculationTypesName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "ChartOfCalculationTypes", "ChartOfCalculationTypes");
	
EndFunction

// Registers

// Determines whether the metadata object is one of Information register type objects by the full 
//  metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is an information register.
//
Function IsFullInformationRegisterName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "InformationRegister", "InformationRegister");
	
EndFunction

// Determines whether the metadata object is one of Accumulation register type objects by the full 
//  metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is an accumulation register.
//
Function IsFullAccumulationRegisterName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "AccumulationRegister", "AccumulationRegister");
	
EndFunction

// Determines whether the metadata object is one of Accounting register type objects by the full 
//  metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is an accounting register.
//
Function IsFullAccountingRegisterName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "AccountingRegister", "AccountingRegister");
	
EndFunction

// Determines whether the metadata object is one of Calculation register type objects by the full 
//  metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a calculation register.
//
Function IsFullCalculationRegisterName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "CalculationRegister", "CalculationRegister")
		AND Not IsFullRecalculationName(FullName);
	
EndFunction

// Recalculations

// Determines whether the metadata object is one of Recalculation type objects by the full metadata 
//  object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a recalculation.
//
Function IsFullRecalculationName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Recalculation", "Recalculation", 2);
	
EndFunction

// Constants

// Determines whether the metadata object is one of Constant type objects by the full metadata 
//  object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a constant.
//
Function IsFullConstantName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Constant", "Constant");
	
EndFunction

// Document journals

// Determines whether the metadata object is one of Document journal type objects by the full 
//  metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a document journal.
//
Function IsFullDocumentJournalName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "DocumentJournal", "DocumentJournal");
	
EndFunction

// Sequences

// Determines whether the metadata object is one of Sequence type objects by the full metadata 
//  object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a sequence.
//
Function IsFullSequenceName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "Sequence", "Sequence");
	
EndFunction

// ScheduledJobs

// Determines whether the metadata object is one of Scheduled job type objects by the full metadata 
//  object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a scheduled job.
//
Function ThisFullScheduledJobName(Val FullName) Export
	
	Return CheckMetadataObjectTypeByFullName(FullName, "ScheduledJob", "ScheduledJob");
	
EndFunction

// Common

// Determines whether the metadata object is one of register type objects by the full metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object is a register.
//
Function IsFullRegisterName(Val FullName) Export
	
	Return IsFullInformationRegisterName(FullName)
		OR IsFullAccumulationRegisterName(FullName)
		OR IsFullAccountingRegisterName(FullName)
		OR IsFullCalculationRegisterName(FullName);
	
EndFunction

// Determines whether the metadata object is one of reference type objects by the full metadata object name.
//
// Parameters:
//  FullName - String - full name of the metadata object whose type must be compared with the 
//   specified type.
//
// Returns:
//  Boolean - True if the object has a reference type.
//
Function IsFullReferenceTypeObjectName(Val FullName) Export
	
	Return IsFullCatalogName(FullName)
		OR IsFullDocumentName(FullName)
		OR IsFullBusinessProcessName(FullName)
		OR IsFullTaskName(FullName)
		OR IsFullChartOfAccountsName(FullName)
		OR IsFullExchangePlanName(FullName)
		OR IsFullChartOfCharacteristicTypesName(FullName)
		OR IsFullChartOfCalculationTypesName(FullName);
	
EndFunction

// Selection parameters by the full name of the metadata object.
//
// Parameters:
//   MetadataObjectFullName - String - full name of a metadata object.
//
// Returns:
//   Structure - the selection parameters.
//
Function SelectionParameters(Val FullMetadataObjectName) Export
	
	Result = New Structure("Table,FieldNameRecorder");
	
	If IsFullRegisterName(FullMetadataObjectName)
			OR IsFullSequenceName(FullMetadataObjectName) Then
		
		Result.Table = FullMetadataObjectName;
		Result.FieldNameRecorder = "Recorder";
		
	ElsIf IsFullRecalculationName(FullMetadataObjectName) Then
		
		Substrings = StrSplit(FullMetadataObjectName, ".");
		Result.Table = Substrings[0] + "." + Substrings[1] + "." + Substrings[3];
		Result.FieldNameRecorder = "RecalculationObject";
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Функция SelectionParameters() не должна использоваться для объекта %1.'; en = 'The SelectionParameters() function cannot be executed for the %1 object.'; pl = 'Funkcja SelectionParameters() nie powinna być używana dla %1 obiektu.';es_ES = 'La función ParametersSelections() no tiene que utilizarse para el objeto %1.';es_CO = 'La función ParametersSelections() no tiene que utilizarse para el objeto %1.';tr = 'SelectionParameters() işlevi %1 nesnesi için kullanılmamalıdır.';it = 'La funzione dei ParametriDiSelezione() non deve essere utilizzata per l''oggetto %1.';de = 'Die Funktion SelectionParameters() sollte nicht für das Objekt verwendet werden %1.'"),
			FullMetadataObjectName);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Name of the event in the event log to record data area copy errors.
//
// Returns:
//	String - error event name.
//
Function EventLogEventDataAreaCopying() Export
	
	Return NStr("ru = 'Работа в модели сервиса.Копирование области данных'; en = 'SaaS operations. Copying data area'; pl = 'Praca w modelu usługi.Kopiowanie obszaru danych';es_ES = 'Trabajo en el modelo de servicio.Copia del área de datos';es_CO = 'Trabajo en el modelo de servicio.Copia del área de datos';tr = 'Servis modelinde çalışma. Veri alanın kopyalanması';it = 'Operazioni SaaS. Copia area dati in corso';de = 'Arbeiten in einem Servicemodell. Kopieren des Datenbereichs'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Name of the event in the event log to record data area lock errors.
//
// Returns:
//	String - error event name.
//
Function EventLogEventDataAreaLock() Export
	
	Return NStr("ru = 'Работа в модели сервиса.Блокировка области данных'; en = 'SaaS operations. Lock of data area'; pl = 'Praca w modelu usługi.Blokowanie obszaru danych';es_ES = 'Trabajo en el modelo de servicio.Bloqueo del área de datos';es_CO = 'Trabajo en el modelo de servicio.Bloqueo del área de datos';tr = 'Servis modelinde çalışma. Veri alanın kilitlenmesi';it = 'Operazioni SaaS. Blocco area dati';de = 'Arbeiten in einem Servicemodell. Sperren des Datenbereichs'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Name of the event in the event log to record data area preparation errors.
//
// Returns:
//	String - error event name.
//
Function EventLogEventDataAreaPreparation() Export
	
	Return NStr("ru = 'Работа в модели сервиса.Подготовка области данных'; en = 'SaaS operations. Data area preparation'; pl = 'Praca w modelu usługi.Przygotowanie obszaru danych';es_ES = 'Trabajo en el modelo de servicio.Preparación del área de datos';es_CO = 'Trabajo en el modelo de servicio.Preparación del área de datos';tr = 'Servis modelinde çalışma. Veri alanın hazırlanması';it = 'Operazioni Saas. Preparazione area dati in corso';de = 'Arbeiten in einem Servicemodell. Vorbereitung des Datenbereichs'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Name of the event in the event log to record errors occurred while receiving file form storage.
//
// Returns:
//	String - error event name.
//
Function EventLogEventReceivingFileFromStorage() Export
	
	Return NStr("ru = 'Работа в модели сервиса.Получение файла из хранилища'; en = 'SaaS operations. Receiving file from the storage'; pl = 'Praca w modelu usługi.Pobierz plik z magazynu';es_ES = 'Trabajo en el modelo de servicio.Recepción del archivo del almacenamiento';es_CO = 'Trabajo en el modelo de servicio.Recepción del archivo del almacenamiento';tr = 'Servis modelinde çalışma. Depolama alanından dosya alma';it = 'Operazioni SaaS. Acquisizione file dall''archivio';de = 'Arbeiten in einem Servicemodell. Empfangen einer Datei aus dem Speicher'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Name of the event in the event log to record errors occurred while adding file on exchange through the file system.
//
// Returns:
//	String - error event name.
//
Function EventLogEventAddingFileExchangeThroughFS() Export
	
	Return NStr("ru = 'Работа в модели сервиса.Добавление файла.Обмен через ФС'; en = 'SaaS operations. Adding file. Exchange through FS'; pl = 'Praca w modelu usługi. Dodawanie pliku. Udostępnianie przez SP';es_ES = 'Trabajo en el modelo de servicio. Añadir el archivo. Intercambio a través de Sistema de archivos';es_CO = 'Trabajo en el modelo de servicio. Añadir el archivo. Intercambio a través de Sistema de archivos';tr = 'Servis modelinde çalışma. Dosya ekleme. FS üzerinden alışveriş';it = 'Operazioni SaaS. Aggiunta file. Scambio tramite FS';de = 'Arbeiten in einem Servicemodell. Hinzufügen einer Datei. Austausch über DS'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Name of the event in the event log to record errors occurred while adding file on exchange not through the file system.
//
// Returns:
//	String - error event name.
//
Function EventLogEventAddingFileExchangeNotThroughFS() Export
	
	Return NStr("ru = 'Работа в модели сервиса.Добавление файла.Обмен не через ФС'; en = 'SaaS operations. Adding file. Exchange not through FS'; pl = 'Praca w modelu usługi. Dodawanie pliku. Wymiana poza SP';es_ES = 'Trabajo en el modelo de servicio. Añadir el archivo. Intercambio no a través de Sistema de archivos';es_CO = 'Trabajo en el modelo de servicio. Añadir el archivo. Intercambio no a través de Sistema de archivos';tr = 'Servis modelinde çalışma. Dosya ekleme. FS üzerinden olmayan alışveriş';it = 'Operazioni SaaS. Aggiunta file. Scambio non tramite FS';de = 'Arbeiten in einem Servicemodell. Hinzufügen einer Datei. Austausch nicht über DS'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Name of the event in the event log to record errors occurred while deleting the temporary file.
//
// Returns:
//	String - error event name.
//
Function TempFileDeletionEventLogMessageText() Export
	
	Return NStr("ru = 'Работа в модели сервиса.Удаление временного файла'; en = 'SaaS operations. Temporary file deletion'; pl = 'Praca w modelu usługi.Usuwanie pliku tymczasowego';es_ES = 'Trabajo en el modelo de servicio.Eliminación del archivo temporal';es_CO = 'Trabajo en el modelo de servicio.Eliminación del archivo temporal';tr = 'Servis modelinde çalışma. Geçici dosyayı sil';it = 'Operazioni SaaS. Eliminazione file temporanei';de = 'Arbeiten in einem Servicemodell. Löschen einer temporären Datei'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Other procedures and functions

// See SaaSOverridable.OnFillIBParametersTable. 
Procedure OnFillIIBParametersTable(Val ParametersTable) Export
	
	If IsSeparatedConfiguration() Then
		AddConstantToIBParametersTable(ParametersTable, "UseSeparationByDataAreas");
		
		AddConstantToIBParametersTable(ParametersTable, "InfobaseUsageMode");
		
		AddConstantToIBParametersTable(ParametersTable, "CopyDataAreasFromPrototype");
	EndIf;
	
	AddConstantToIBParametersTable(ParametersTable, "InternalServiceManagerURL");
	
	CurParameterString = ParametersTable.Add();
	CurParameterString.Name = "InternalServiceManagerURL";
	CurParameterString.Details = NStr("ru = 'Внутренний адрес Менеджера сервиса'; en = 'Internal service manager URL'; pl = 'Wewnętrzny adres URL menedżera usług';es_ES = 'URL del administrador de servicio interno';es_CO = 'URL del administrador de servicio interno';tr = 'Dahili servis yöneticisi URL''si';it = 'Indirizzo interno del manager di servizio';de = 'Internes URL des Service-Managers'");
	CurParameterString.Type = New TypeDescription("String");
	
	// For obsolete version compatibility the "URLService" parameter is required
	CurParameterString = ParametersTable.Add();
	CurParameterString.Name = "ServiceURL";
	CurParameterString.Details = NStr("ru = 'Внутренний адрес Менеджера сервиса'; en = 'Internal service manager URL'; pl = 'Wewnętrzny adres URL menedżera usług';es_ES = 'URL del administrador de servicio interno';es_CO = 'URL del administrador de servicio interno';tr = 'Dahili servis yöneticisi URL''si';it = 'Indirizzo interno del manager di servizio';de = 'Internes URL des Service-Managers'");
	CurParameterString.Type = New TypeDescription("String");
	
	CurParameterString = ParametersTable.Add();
	CurParameterString.Name = "AuxiliaryServiceManagerUsername";
	CurParameterString.Details = "AuxiliaryServiceManagerUsername";
	CurParameterString.Type = New TypeDescription("String");
	
	CurParameterString = ParametersTable.Add();
	CurParameterString.Name = "AuxiliaryServiceManagerUserPassword";
	CurParameterString.Details = "AuxiliaryServiceManagerUserPassword";
	CurParameterString.Type = New TypeDescription("String");
	CurParameterString.ReadProhibition = True;
	
	CurParameterString = ParametersTable.Add();
	CurParameterString.Name = "AuxiliaryServiceUsername";
	CurParameterString.Details = "AuxiliaryServiceUsername";
	CurParameterString.Type = New TypeDescription("String");
	
	CurParameterString = ParametersTable.Add();
	CurParameterString.Name = "AuxiliaryServiceUserPassword";
	CurParameterString.Details = "AuxiliaryServiceUserPassword";
	CurParameterString.Type = New TypeDescription("String");
	CurParameterString.ReadProhibition = True;
	// End For obsolete version compatibility.
	
	CurParameterString = ParametersTable.Add();
	CurParameterString.Name = "ConfigurationVersion";
	CurParameterString.Details = NStr("ru = 'Версия конфигурации'; en = 'Configuration version'; pl = 'Wersja konfiguracji';es_ES = 'Versión de la configuración';es_CO = 'Versión de la configuración';tr = 'Yapılandırma sürümü';it = 'Versione configurazione';de = 'Konfigurationsversion'");
	CurParameterString.WriteProhibition = True;
	CurParameterString.Type = New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable));
	
	SSLSubsystemsIntegration.OnFillIIBParametersTable(ParametersTable);
	
EndProcedure

// Retrieves file description by its ID in the File register.
// If disk storage and PathNotData = True, Data in the result structure = Undefined, FullName = Full 
// file name, otherwise Data is binary file data, FullName - Undefined.
// 
// The Name key value always contains the name in the storage.
//
// Parameters:
//   FileID - UUID - a file UUID.
//   ConnectionParameters - Structure - the following fields:
//							* URL - String - service URL mandatory to be filled in,
//							* UserName - String - service user name,
//							* Password - String - service user password,
//   PathNotData - Boolean - what to return,
//   CheckForExistence - Boolean - flag that shows whether the file existence must be checked if it cannot be retrieved.
//		
// Returns:
//   Structure - file description:
//	   * Name - String - file name in the storage.
//	   * Data - BinaryData - file data.
//	   * FullName - String - file full name (the file is automatically deleted once the temporary file storing time is up).
//
Function GetFileFromStorage(Val FileID, Val ConnectionParameters, 
	Val PathNotData = False, Val CheckForExistence = False) Export
	
	ExecutionStarted = CurrentUniversalDate();
	
	ProxyDetails = FileTransferServiceProxyDetails(ConnectionParameters);
	
	ExchangeOverFS = CanPassViaFSFromServer(ProxyDetails.Proxy, ProxyDetails.HasSecondVersionSupport);
	
	If ExchangeOverFS Then
			
		Try
			Try
				FileName = ProxyDetails.Proxy.WriteFileToFS(FileID);
			Except
				ErrorDescription = DetailErrorDescription(ErrorInfo());
				If CheckForExistence AND Not ProxyDetails.Proxy.FileExists(FileID) Then
					Return Undefined;
				EndIf;
				Raise ErrorDescription;
			EndTry;
			
			FIleProperties = New File(GetCommonTempFilesDir() + FileName);
			If FIleProperties.Exist() Then
				FileDetails = CreateFileDetails();
				FileDetails.Name = FIleProperties.Name;
				
				ReceivedFileSize = FIleProperties.Size();
				
				If PathNotData Then
					FileDetails.Data = Undefined;
					FileDetails.FullName = FIleProperties.FullName;
				Else
					FileDetails.Data = New BinaryData(FIleProperties.FullName);
					FileDetails.FullName = Undefined;
					Try
						DeleteFiles(FIleProperties.FullName);
					Except
						WriteLogEvent(EventLogEventReceivingFileFromStorage(),
							EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
					EndTry;
				EndIf;
				
				WriteFileStorageEventToLog(
					NStr("ru = 'Извлечение'; en = 'Extracting'; pl = 'Wyodrębnienie';es_ES = 'Extraer';es_CO = 'Extraer';tr = 'Çıkarma';it = 'Estrazione';de = 'Auszug'", CommonClientServer.DefaultLanguageCode()),
					FileID,
					ReceivedFileSize,
					CurrentUniversalDate() - ExecutionStarted,
					ExchangeOverFS);
				
				Return FileDetails;
			Else
				ExchangeOverFS = False;
			EndIf;
		Except
			WriteLogEvent(EventLogEventReceivingFileFromStorage(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			ExchangeOverFS = False;
		EndTry;
			
	EndIf; // ExchangeOverFS
	
	PartCount = Undefined;
	FileNameInCatalog = Undefined;
	FileTransferBlockSize = GetFileTransferBlockSize();
	Try
		If ProxyDetails.HasSecondVersionSupport Then
			TransferID = ProxyDetails.Proxy.PrepareGetFile(FileID, FileTransferBlockSize * 1024, PartCount);
		Else
			TransferID = Undefined;
			ProxyDetails.Proxy.PrepareGetFile(FileID, FileTransferBlockSize * 1024, TransferID, PartCount);
		EndIf;
	Except
		ErrorDescription = DetailErrorDescription(ErrorInfo());
		If CheckForExistence AND Not ProxyDetails.Proxy.FileExists(FileID) Then
			Return Undefined;
		EndIf;
		Raise ErrorDescription;
	EndTry;
	
	FileNames = New Array;
	
	BuildDirectory = CreateAssemblyDirectory();
	
	If ProxyDetails.HasSecondVersionSupport Then
		For PartNumber = 1 To PartCount Do
			PartData = ProxyDetails.Proxy.GetFilePart(TransferID, PartNumber, PartCount);
			FileNamePart = BuildDirectory + "part" + Format(PartNumber, "ND=4; NLZ=; NG=");
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
	Else // 1st version.
		For PartNumber = 1 To PartCount Do
			PartData = Undefined;
			ProxyDetails.Proxy.GetFilePart(TransferID, PartNumber, PartData);
			FileNamePart = BuildDirectory + "part" + Format(PartNumber, "ND=4; NLZ=; NG=");
			PartData.Write(FileNamePart);
			FileNames.Add(FileNamePart);
		EndDo;
	EndIf;
	PartData = Undefined;
	
	ProxyDetails.Proxy.ReleaseFile(TransferID);
	
	ArchiveName = GetTempFileName("zip");
	
	Try
	
		MergeFiles(FileNames, ArchiveName);
		FileMerged = True;
		
	Except
		
		FileMerged = False;
		WriteLogEvent(NStr("ru = 'Выполнение операции объединения файлов'; en = 'Merging files'; pl = 'Przeprowadzanie operacji scalania plików';es_ES = 'Ejecución de la operación unión de archivos';es_CO = 'Ejecución de la operación unión de archivos';tr = 'Dosya birleştirme işlemi yürütülüyor';it = 'Unione file';de = 'Durchführen einer Dateizusammenführung'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			
	EndTry;
	
	If FileMerged Then
		
		Try
		
			ZipFileReader = New ZipFileReader(ArchiveName);
			ZipFileRead = True;
			
		Except
			
			ZipFileRead = False;
			WriteLogEvent(NStr("ru = 'Выполнение операции чтения zip файла'; en = 'Reading zip file'; pl = 'Przeprowadzanie operacji odczytu pliku zip';es_ES = 'Realización de la operación de leer el archivo zip';es_CO = 'Realización de la operación de leer el archivo zip';tr = 'Zip dosya okuma işlemi yürütülüyor';it = 'Lettura file zip';de = 'Durchführen eines Lesevorgangs für Zip-Dateien'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				
		EndTry;
		
		If ZipFileRead Then
			
			ReceivedArchiveContainsMoreThanOneFile = ZipFileReader.Items.Count() > 1;
			
			If NOT ReceivedArchiveContainsMoreThanOneFile Then
				
				FileName = BuildDirectory + ZipFileReader.Items[0].Name;
				ZipFileReader.Extract(ZipFileReader.Items[0], BuildDirectory);
				ZipFileReader.Close();
				
				ResultFile = New File(GetTempFileName());
				MoveFile(FileName, ResultFile.FullName);
				ReceivedFileSize = ResultFile.Size();
				
				FileDetails = CreateFileDetails();
				FileDetails.Name = ResultFile.Name;
				
				If PathNotData Then
					
					FileDetails.Data = Undefined;
					FileDetails.FullName = ResultFile.FullName;
					
				Else
					
					FileDetails.Data = New BinaryData(ResultFile.FullName);
					FileDetails.FullName = Undefined;
					
					Try
						
						DeleteFiles(ResultFile.FullName);
						
					Except
						
						WriteLogEvent(EventLogEventReceivingFileFromStorage(),
							EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
							
					EndTry;
						
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	TemporaryFile = New File(ArchiveName);
	
	If TemporaryFile.Exist() Then
		
		Try
			
			TemporaryFile.SetReadOnly(False);
			DeleteFiles(ArchiveName);
			
		Except
			
			WriteLogEvent(NStr("ru = 'Выполнение операции удаления временного файла'; en = 'Deleting temporary file'; pl = 'Usunięcie plików tymczasowych';es_ES = 'Eliminando el archivo temporal';es_CO = 'Eliminando el archivo temporal';tr = 'Geçici dosya siliniyor';it = 'Eseguire file temporanei operazioni di cancellazione';de = 'Temporäre Datei löschen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
				
		EndTry;
		
	EndIf;
	
	Try
		
		DeleteFiles(BuildDirectory);
		
	Except
		
		WriteLogEvent(EventLogEventReceivingFileFromStorage(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			
	EndTry;
		
	If NOT ZipFileRead Then
		
		Raise(NStr("ru = 'При чтении zip файла произошла ошибка.'; en = 'An error occurred when reading zip file.'; pl = 'Wystąpił błąd podczas odczytu pliku zip.';es_ES = 'Al leer el archivo zip ha ocurrido un error.';es_CO = 'Al leer el archivo zip ha ocurrido un error.';tr = 'Zip dosya okunurken bir hata oluştu.';it = 'Errore durante la lettura del file zip.';de = 'Beim Lesen der Zip-Datei ist ein Fehler aufgetreten.'"));
		
	EndIf;
	
	If ReceivedArchiveContainsMoreThanOneFile Then
		
		Raise(NStr("ru = 'В полученном архиве содержится более одного файла.'; en = 'The archive contains more than one file.'; pl = 'Wynikowe archiwum zawiera więcej niż jeden plik.';es_ES = 'El archivo recibido contiene más de un archivo.';es_CO = 'El archivo recibido contiene más de un archivo.';tr = 'Elde edilen arşivde birden fazla dosya bulunmaktadır.';it = 'L''archivio contiene più di un file.';de = 'Das empfangene Archiv enthält mehr als eine Datei.'"));
		
	EndIf;
	
	WriteFileStorageEventToLog(
		NStr("ru = 'Извлечение'; en = 'Extracting'; pl = 'Wyodrębnienie';es_ES = 'Extraer';es_CO = 'Extraer';tr = 'Çıkarma';it = 'Estrazione';de = 'Auszug'", CommonClientServer.DefaultLanguageCode()),
		FileID,
		ReceivedFileSize,
		CurrentUniversalDate() - ExecutionStarted,
		ExchangeOverFS);
	
	Return FileDetails;
	
EndFunction

// Writes the test file to the disk returning its name and size.
// The calling side must delete this file.
//
// Returns:
//   String - test file name without a path.
//
Function WriteTestFile() Export
	
	NewID = New UUID;
	FIleProperties = New File(GetCommonTempFilesDir() + NewID + ".tmp");
	
	Text = New TextWriter(FIleProperties.FullName, TextEncoding.ANSI);
	Text.Write(NewID);
	Text.Close();
	
	Return FIleProperties.Name;
	
EndFunction

// Additional actions when changing session separation.
//
Procedure DataAreaOnChange() Export
	
	ClearAllSessionParametersExceptSeparators();
	
	If SeparatedDataUsageAvailable()
		AND CurrentRunMode() <> Undefined Then
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.Read();
		
		If RecordManager.Selected() Then
			
			If NOT (RecordManager.ProcessingError
				OR RecordManager.Status = Enums.DataAreaStatuses.ForDeletion
				OR RecordManager.Status = Enums.DataAreaStatuses.Deleted) Then
		
				UsersInternal.AuthenticateCurrentUser();
			
			EndIf;
			
		Else
			
			UsersInternal.AuthenticateCurrentUser();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Registers supplied data handlers for the day and for all time.
//
// Parameters:
//   Handlers - ValueTable - a table of handlers.
//
Procedure RegisterSuppliedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "DataAreaPrototype";
	Handler.HandlerCode = "DataAreaPrototype";
	Handler.Handler = SaaS;
	
EndProcedure

// The procedure is called when a new data notification is received.
// In the procedure body, check whether the application requires this data. If it does, select the 
// Import check box.
// 
// Parameters:
//   Descriptor - XDTODataObject - Descriptor.
//   Import - Boolean - return value.
//
Procedure NewDataAvailable(Val Descriptor, Import) Export
	
	If Descriptor.DataType = "DataAreaPrototype" Then
		ConfigurationNameCondition = False;
		ConfigurationVersionCondition = False;
		For each Characteristic In Descriptor.Properties.Property Do
			If Not ConfigurationNameCondition Then
				ConfigurationNameCondition = Characteristic.Code = "ConfigurationName" AND Characteristic.Value = Metadata.Name;
			EndIf;
			If Not ConfigurationVersionCondition Then
				ConfigurationVersionCondition = Characteristic.Code = "ConfigurationVersion"
					AND CommonClientServer.CompareVersions(Characteristic.Value, Metadata.Version) >= 0;
			EndIf;
		EndDo;
		Import = ConfigurationNameCondition AND ConfigurationVersionCondition;
	EndIf;
	
EndProcedure

// The procedure is called after calling NewDataAvailable, it parses the data.
//
// Parameters:
//   Descriptor - XDTODataObject - a descriptor,
//   PathToFile - String – extracted file full name. The file is automatically deleted once the procedure is executed,
//              - Undefined - if the file is not specified in service manager.
//
Procedure ProcessNewData(Val Descriptor, Val PathToFile) Export
	
	If Descriptor.DataType = "DataAreaPrototype" Then
		HandleSuppliedAppliedSolutionPrototype(Descriptor, PathToFile);
	EndIf;
	
EndProcedure

// The procedure is called if data processing is canceled due to an error.
//
// Parameters:
//   Descriptor - XDTODataObject - a descriptor.
//
Procedure DataProcessingCanceled(Val Descriptor) Export 
	
EndProcedure

// For SaaSCached common module.

// Determines if the session was started without separators.
//
// Returns:
//   Boolean - True if the session is started without separators.
//
Function SessionWithoutSeparators() Export
	
	Return InfoBaseUsers.CurrentUser().DataSeparation.Count() = 0;
	
EndFunction

// Returns a flag that shows if there are any common separators in the configuration.
//
// Returns:
//   Boolean - True if the configuration is separated.
//
Function IsSeparatedConfiguration() Export
	
	Return SaaSCached.IsSeparatedConfiguration();
	
EndFunction

// Returns a flag that shows whether the metadata object is used in common separators.
//
// Parameters:
//   MetadataObject - String - metadata object name.
//   Separator - String - the name of the common separator that is checked if it separates the metadata object.
//
// Returns:
//   Boolean - True if the object is separated.
//
Function IsSeparatedMetadataObject(Val MetadataObject, Val Separator = Undefined) Export
	
	If TypeOf(MetadataObject) = Type("String") Then
		FullMetadataObjectName = MetadataObject;
	Else
		FullMetadataObjectName = MetadataObject.FullName();
	EndIf;
	
	Return SaaSCached.IsSeparatedMetadataObject(FullMetadataObjectName, Separator);
	
EndFunction

// Returns an array of serialized structural types currently supported.
//
// Returns:
//   FixedArray - items of Type type.
//
Function StructuralTypesToSerialize() Export
	
	Return SaaSCached.StructuralTypesToSerialize();
	
EndFunction

// Returns the endpoint to send messages to the service manager.
//
// Returns:
//  ExchangePlanRef.MessageExchange - node matching the service manager.
//
Function ServiceManagerEndpoint() Export
	
	ModuleToCall = Common.CommonModule("SaaSCTL");
	Return ModuleToCall.ServiceManagerEndpoint();
	
EndFunction

// Returns mapping between user contact information kinds and kinds.
// Contact information used in the XDTO SaaS.
//
// Returns:
//  Map - mapping between CI kinds.
//
Function ContactInformationKindAndXDTOUserMap() Export
	
	Return SaaSCached.ContactInformationKindAndXDTOUserMap();
	
EndFunction

// Returns mapping between user contact information kinds and XDTO kinds.
// User CI.
//
// Returns:
//  Map - mapping between CI kinds.
//
Function XDTOContactInformationKindAndUserContactInformationKindMap() Export
	
	Return SaaSCached.XDTOContactInformationKindAndUserContactInformationKindMap();
	
EndFunction

// Returns mapping between XDTO rights used in SaaS and possible actions with SaaS user.
// 
// 
// Returns:
//  Map - mapping between rights and actions.
//
Function XDTORightAndServiceUserActionMap() Export
	
	Return SaaSCached.XDTORightAndServiceUserActionMap();
	
EndFunction

// Returns data model details of data area.
//
// Returns:
//  FixedMap - area data model
//    * Key - MetadataObject - a metadata object,
//    * Value - String - the name of the common attribute separator.
//
Function GetDataAreaModel() Export
	
	Return SaaSCached.GetDataAreaModel();
	
EndFunction

// Returns an array of the separators that are in the configuration.
//
// Returns:
//   FixedArray - an array of common attribute names used as separators.
//     
//
Function ApplicationSeparators() Export
	
	Return SaaSCached.ApplicationSeparators();
	
EndFunction

// Returns the common attribute content by the passed name.
//
// Parameters:
//   Name - String - common attribute name.
//
// Returns:
//   CommonAttributeContent - list of metadata objects that include the common attribute.
//
Function CommonAttributeContent(Val Name) Export
	
	Return SaaSCached.CommonAttributeContent(Name);
	
EndFunction


#Region ObsoleteProceduresAndFunctions

// Obsolete. Use the SetExclusiveMode(True) platform method.
//
// Parameters:
//  CheckNoOtherSessions - Boolean - flag that shows whether a search for other user sessions.
//  SeparatedLock - Boolean - this lock is separated.
//
Procedure LockCurrentDataArea(Val CheckNoOtherSessions = False, Val SeparatedLock = False) Export
	
	If NOT SeparatedDataUsageAvailable() Then
		Raise(NStr("ru = 'Блокировка области может быть установлена только при включенном использовании разделителей'; en = 'Area can be locked only when separator usage is enabled'; pl = 'Obszar można zablokować tylko wtedy, gdy włączone jest użycie separatora';es_ES = 'Área puede bloquearse solo cuando el uso de separador está activado';es_CO = 'Área puede bloquearse solo cuando el uso de separador está activado';tr = 'Alan sadece ayırıcı kullanımı etkinleştirildiğinde kilitlenebilir';it = 'Area può essere bloccato solo quando l''utilizzo di separazione è abilitato';de = 'Bereich kann nur gesperrt werden, wenn die Separator-Verwendung aktiviert ist'"));
	EndIf;
	
	varKey = CreateAuxiliaryDataInformationRegisterRecordKey(
		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), SessionSeparatorValue()));
	
	AttemptCount = 5;
	CurrentAttempt = 0;
	While True Do
		Try
			LockDataForEdit(varKey);
			Break;
		Except
			CurrentAttempt = CurrentAttempt + 1;
			
			If CurrentAttempt = AttemptCount Then
				CommentTemplate = NStr("ru = 'Не удалось установить блокировку области данных по причине:
					|%1'; 
					|en = 'Cannot lock the data area due to:
					|%1'; 
					|pl = 'Nie udało się ustawić blokady obszaru danych z powodu:
					|%1';
					|es_ES = 'No se puede bloquear el área de datos a causa de: 
					|%1';
					|es_CO = 'No se puede bloquear el área de datos a causa de: 
					|%1';
					|tr = 'Aşağıdaki nedenle veri alanı kilitlenemedi: 
					|%1';
					|it = 'Non è stato possibile impostare il blocco dell''area dati per: 
					|%1';
					|de = 'Eine Sperrung des Datenbereichs war aus diesem Grund nicht möglich:
					|%1'");
				CommentText = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, DetailErrorDescription(ErrorInfo()));
				WriteLogEvent(EventLogEventDataAreaLock(),
					EventLogLevel.Error,
					,
					,
					CommentText);
					
				TextPattern = NStr("ru = 'Не удалось установить блокировку области данных по причине:
					|%1'; 
					|en = 'Cannot lock the data area due to:
					|%1'; 
					|pl = 'Nie udało się ustawić blokady obszaru danych z powodu:
					|%1';
					|es_ES = 'No se puede bloquear el área de datos a causa de: 
					|%1';
					|es_CO = 'No se puede bloquear el área de datos a causa de: 
					|%1';
					|tr = 'Aşağıdaki nedenle veri alanı kilitlenemedi: 
					|%1';
					|it = 'Non è stato possibile impostare il blocco dell''area dati per: 
					|%1';
					|de = 'Eine Sperrung des Datenbereichs war aus diesem Grund nicht möglich:
					|%1'");
				Text = StringFunctionsClientServer.SubstituteParametersToString(TextPattern, BriefErrorDescription(ErrorInfo()));
					
				Raise(Text);
			EndIf;
		EndTry;
	EndDo;
	
	If CheckNoOtherSessions Then
		
		ConflictingSessions = New Array();
		
		For each Session In GetInfoBaseSessions() Do
			If Session.SessionNumber = InfoBaseSessionNumber() Then
				Continue;
			EndIf;
			
			ClientApplications = New Array;
			ClientApplications.Add(Upper("1CV8"));
			ClientApplications.Add(Upper("1CV8C"));
			ClientApplications.Add(Upper("WebClient"));
			ClientApplications.Add(Upper("COMConnection"));
			ClientApplications.Add(Upper("WSConnection"));
			ClientApplications.Add(Upper("BackgroundJob"));
			If ClientApplications.Find(Upper(Session.ApplicationName)) = Undefined Then
				Continue;
			EndIf;
			
			ConflictingSessions.Add(Session);
			
		EndDo;
		
		If ConflictingSessions.Count() > 0 Then
			
			UnlockDataForEdit(varKey);
			
			SessionsText = "";
			For Each ConflictingSession In ConflictingSessions Do
				
				If Not IsBlankString(SessionsText) Then
					SessionsText = SessionsText + ", ";
				EndIf;
				
				SessionsText = SessionsText + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '%1 (сеанс - %2)'; en = '%1 (session %2)'; pl = '%1 (sesja %2)';es_ES = '%1 (sesión %2)';es_CO = '%1 (sesión %2)';tr = '%1 (oturum %2)';it = '%1 (sessione %2)';de = '%1 (Sitzung - %2)'", CommonClientServer.DefaultLanguageCode()),
					ConflictingSession.User.Name,
					Format(ConflictingSession.SessionNumber, "NG=0"));
				
			EndDo;
			
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Операция не может быть выполнена, т.к. в приложении работают другие пользователи: %1'; en = 'Operation cannot be performed as other users are using the application: %1'; pl = 'Operacja nie może być wykonana ponieważ w aplikacji pracują inni użytkownicy: %1';es_ES = 'Operación no puede realizarse porque otros usuarios están utilizando la aplicación: %1';es_CO = 'Operación no puede realizarse porque otros usuarios están utilizando la aplicación: %1';tr = 'Diğer kullanıcılar uygulama kullanıyor olduğundan işlem yapılamaz:%1';it = 'L''operazione non può essere eseguita, perché altri utenti stanno lavorando nell''app: %1';de = 'Die Operation kann nicht ausgeführt werden, da andere Benutzer die Anwendung verwenden: %1'",
					CommonClientServer.DefaultLanguageCode()),
				SessionsText);
				
			Raise ExceptionText;
			
		EndIf;
		
	EndIf;
	
	If NOT SeparatedLock Then
		SetExclusiveMode(True);
		Return;
	EndIf;
	
	DataModel = SaaSCached.GetDataAreaModel();
	
	Lock = New DataLock;
	
	For Each ModelItem In DataModel Do
		
		FullMetadataObjectName = ModelItem.Key;
		MetadataObjectDetails = ModelItem.Value;
		
		LockSpace = FullMetadataObjectName;
		
		If IsFullRegisterName(FullMetadataObjectName) Then
			
			LockSets = True;
			If IsFullInformationRegisterName(FullMetadataObjectName) Then
				AreaMetadataObject = Metadata.InformationRegisters.Find(MetadataObjectDetails.Name);
				If AreaMetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					LockSets = False;
				EndIf;
			EndIf;
			
			If LockSets Then
				LockSpace = LockSpace + ".RecordSet";
			EndIf;
			
		ElsIf IsFullSequenceName(FullMetadataObjectName) Then
			
			LockSpace = LockSpace + ".Records";
			
		ElsIf IsFullDocumentJournalName(FullMetadataObjectName)
				OR IsFullEnumerationName(FullMetadataObjectName)
				OR IsFullSequenceName(FullMetadataObjectName)
				OR ThisFullScheduledJobName(FullMetadataObjectName) Then
			
			Continue;
			
		EndIf;
		
		LockItem = Lock.Add(LockSpace);
		
		If SeparatedLock Then
			
			LockItem.Mode = DataLockMode.Shared;
			
		EndIf;
		
	EndDo;
	
	Lock.Lock();
	
EndProcedure

// Obsolete. Use the SetExclusiveMode(False) platform method.
Procedure UnlockCurrentDataArea() Export
	
	varKey = CreateAuxiliaryDataInformationRegisterRecordKey(
		InformationRegisters.DataAreas,
		New Structure(AuxiliaryDataSeparator(), SessionSeparatorValue()));
		
	UnlockDataForEdit(varKey);
	
	SetExclusiveMode(False);
	
EndProcedure

#EndRegion

#EndRegion

#Region Internal

// Returns a list of full names of all metadata objects used in the common separator attribute 
//  (whose name is passed in the Separator parameter) and values of the object metadata properties 
//  that can be required for further processing in universal algorithms.
// In case of sequences and document journals the function determines whether they are separated by included documents: any one from the sequence or journal.
//
// Parameters:
//  Separator - string, name of the common separator.
//
// Returns:
// FixedMap,
//  Key - string, full name of the metadata object,
//  Value - FixedStructure,
//    Name - string, name of the metadata object,
//    Separator - string, name of the separator that separates the metadata object,
//    ConditionalSeparation - String - full name of the metadata object that shows whether the 
//      metadata object data separation is enabled.
//
Function SeparatedMetadataObjects(Val Separator) Export
	
	Return SaaSCached.SeparatedMetadataObjects(Separator);
	
EndFunction

// Parameters:
//  MetadataJob - MetadataObject - predefined scheduled job metadata.
//  Usage - Boolean - True if the job must be activated, False otherwise.
//
Procedure SetPredefinedScheduledJobUsage(MetadataJob, Usage) Export
	
	Template = JobQueue.TemplateByName(MetadataJob.Name);
	
	JobFilter = New Structure;
	JobFilter.Insert("Template", Template);
	Jobs = JobQueue.GetJobs(JobFilter);
	
	If Jobs.Count() = 0 Then
		ExclusiveMode = ExclusiveMode();
		If Not ExclusiveMode Then
			Try
				SetExclusiveMode(True);
				ExclusiveModeSet = True;
			Except
				ExclusiveModeSet = False;
			EndTry;
		EndIf;
		If ExclusiveMode() Then
			Try
				JobQueueInternalDataSeparation.CreateQueueJobsByTemplatesInCurrentArea();
				UpdateComplete = True;
			Except
				UpdateComplete = False;
			EndTry;
			If UpdateComplete Then
				Jobs = JobQueue.GetJobs(JobFilter);
			EndIf;
		EndIf;
		If ExclusiveModeSet Then
			SetExclusiveMode(False);
		EndIf;
	EndIf;
	If Jobs.Count() = 0 Then
		MessageTemplate = NStr("ru = 'Не найдено задание в очереди для предопределенного задания с именем %1'; en = 'Job in the queue for predefined job with the %1 name is not found.'; pl = 'Nie znaleziono zadania w kolejce dla predefiniowanego zadania o nazwie %1.';es_ES = 'No se ha encontrado la tarea en la cola para la tarea predefinida con el nombre %1';es_CO = 'No se ha encontrado la tarea en la cola para la tarea predefinida con el nombre %1';tr = '%1 adına sahip önceden tanımlanmış görev için sırada görev bulunamadı';it = 'Il processo in coda per il processo predefinito con nome %1 non è stato trovato.';de = 'Es wurde kein Job in der Warteschlange für einen vordefinierten Job mit Namen %1 gefunden'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, MetadataJob.Name);
		Raise(MessageText);
	EndIf;
	
	JobParameters = New Structure("Use", Usage);
	JobQueue.ChangeJob(Jobs[0].ID, JobParameters);
	
EndProcedure

// Checks whether the configuration can be used SaaS.
//  If the configuration cannot be used in the SaaS, generates an exception and elaborates why the 
//  configuration cannot be used SaaS.
//
Procedure CheckConfigurationUsageAvailabilitySaaS() Export
	
	SubsystemsDetails = StandardSubsystemsCached.SubsystemsDetails().ByNames;
	CTLDetails = SubsystemsDetails.Get("CloudTechnologyLibrary");
	
	If CTLDetails = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'В конфигурацию не внедрена библиотека ""1С:Библиотека технологии сервиса"".
                  |Без внедрения этой библиотеки конфигурация не может использоваться в модели сервиса.
                  |
                  |Для использования этой конфигурации в модели сервиса требуется внедрить библиотеку
                  |""1С:Библиотека технологии сервиса"" версии не младше %1.'; 
                  |en = 'The 1C:Service Technology Library library was not implemented in the configuration.
                  |The configuration cannot be used in SaaS without this library.
                  |
                  |To use this configuration, implement
                  |the 1C:Service Technology Library library in SaaS of the version not earlier than %1.'; 
                  |pl = 'W konfigurację nie została wdrożona biblioteka ""1C:Biblioteka technologii usługi"".
                  |Bez wdrożenia tej biblioteki konfiguracja nie może być stosowana w modelu usługi.
                  |
                  |Aby skorzystać z tej konfiguracji w modelu usług wymaga się wprowadzenia biblioteki
                  |""1C:Biblioteka technologii usługi"" w wersji nie niżej %1.';
                  |es_ES = 'Biblioteca de tecnología de la ""1C:Biblioteca de tecnología del servicio"".
                  |La configuración no puede utilizarse en el modelo de servicio sin esta implementación de la biblioteca.
                  |
                  |Para utilizar esta configuración en el modelo de servicio, se requiere incorporar la biblioteca
                  |""1C:Biblioteca de la tecnología de servicio"" de la versión no más antigua de %1.';
                  |es_CO = 'Biblioteca de tecnología de la ""1C:Biblioteca de tecnología del servicio"".
                  |La configuración no puede utilizarse en el modelo de servicio sin esta implementación de la biblioteca.
                  |
                  |Para utilizar esta configuración en el modelo de servicio, se requiere incorporar la biblioteca
                  |""1C:Biblioteca de la tecnología de servicio"" de la versión no más antigua de %1.';
                  |tr = 'Yapılandırma, entegre 1C: Standart Alt Sistem Kütüphanesi içermez. 
                  |Bu kütüphane entegre değilse, yapılandırma hizmet modelinde kullanılamaz.
                  |
                  | Bu yapılandırmayı hizmet modelinde kullanmak için, 
                  | sürüm veya daha eski sürüm 1C: Standart Alt sistemler kütüphanesi %1 entegre edilmelidir!';
                  |it = 'Nella configurazione non è implementata la biblioteca: ""1C:Libreria della tecnologia del servizio"".
                  |Senza l''implementazione di questa libreria, la configurazione non può essere utilizzata nel modello di servizio.
                  |
                  |Per utilizzare questa configurazione nel modello di servizio, è necessario implementare la libreria
                  |""1C:Libreria della tecnologia del servizio"", versione non precedente a %1.';
                  |de = 'Die ""1C:Service Technology Library"" ist in der Konfiguration nicht implementiert.
                  |Ohne die Einführung dieser Bibliothek kann die Konfiguration nicht im Servicemodell verwendet werden.
                  |
                  |Um diese Konfiguration im Servicemodell zu verwenden, ist es erforderlich, die Version der Bibliothek
                  |""1C:Service Technology Library"" nicht jünger als %1 einzuführen.'", Metadata.DefaultLanguage.LanguageCode),
			RequiredSTLVersion());
		
	Else
		
		CTLVersion = CTLDetails.Version;
		
		If CommonClientServer.CompareVersions(CTLVersion, RequiredSTLVersion()) < 0 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для использования конфигурации в модели сервиса с текущей версией БСП требуется
                      |обновить используемую версию библиотеки ""1С:Библиотека технологии сервиса"".
                      |
                      |Используемая версия: %1, требуется версия не младше %2.'; 
                      |en = 'To use the configuration in SaaS with the current SL version,
                      |update the current version of library 1C:Service Technology Library.
                      |
                      |Current version: %1, version not earlier than %2 is required.'; 
                      |pl = 'Do użytku konfiguracji w modelu usługi z bieżącą wersją BSP wymaga się
                      |zaktualizować stosowaną wersję biblioteki ""1C:Biblioteka technologii usługi"".
                      |
                      |Stosowana wersja: %1, wymaga wersji nie niżej %2.';
                      |es_ES = 'Para utilizar la configuración en el modelo de servicio con la versión SSL actual, se requiere
                      |actualizar la versión utilizada de la ""1C:Biblioteca de la tecnología de servicio"".
                      |
                      |Versión en uso: %1, se requiere una versión no más antigua de %2.';
                      |es_CO = 'Para utilizar la configuración en el modelo de servicio con la versión SSL actual, se requiere
                      |actualizar la versión utilizada de la ""1C:Biblioteca de la tecnología de servicio"".
                      |
                      |Versión en uso: %1, se requiere una versión no más antigua de %2.';
                      |tr = 'BSP''nin 
                      |geçerli sürümüne sahip bir hizmet modelinde yapılandırmayı kullanmak için kullanılan 1C:hizmet teknolojisi Kitaplığı sürümünü güncellenmelidir. 
                      |
                      |Kullanılan sürüm:%1, gerekli sürüm %2daha küçük değildir .';
                      |it = 'Per utilizzare la configurazione nel modello di servizio con la versione corrente della Libreria dei Sottosistemi Standard
                      |, è necessario aggiornare la versione utilizzata della libreria ""1C:Service dei sottosistemi standard""! 
                      |
                      |Versione utilizzata: %1, è richiesta una versione non precedente a %2.';
                      |de = 'Um die Konfiguration im Servicemodell mit der aktuellen Version des BSP zu verwenden,
                      |ist es notwendig, die verwendete Version der Bibliothek ""1C:Service Technology Library"" zu aktualisieren.
                      |
                      |Verwendete Version: %1, erfordert eine Version nicht jünger als %2.'", Metadata.DefaultLanguage.LanguageCode),
				CTLVersion, RequiredSTLVersion());
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Calls an exception if there is no required subsystem from the cloud technology library.
//
// Parameters:
//  SubsystemName - String.
//
Procedure RaiseNoCTLSubsystemException(Val SubsystemName) Export
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Невозможно выполнить операцию по причине - в конфигурации не внедрена подсистема ""%1"".
              |Данная подсистема поставляется в состав библиотеки технологии сервиса, которая должна отдельно внедряться в состав конфигурации.
              |Проверьте наличие и корректность внедрения подсистемы ""%1"".'; 
              |en = 'Cannot execute operation: subsystem ""%1"" is not implemented in the configuration.
              |This subsystem is included in service technology library which should be implemented separately in the configuration set.
              |Check the existence of subsystem ""%1""  and verify its proper implementation.'; 
              |pl = 'Nie można wykonać operacji, ponieważ podsystem ""%1"" nie jest zaimplementowany w konfiguracji.
              |Ten podsystem jest wprowadzany do biblioteki technologii usług, która powinna być osobno osadzona w skład konfiguracji.
              |Sprawdź, czy podsystem ""%1"" istnieje i jest poprawnie zaimplementowany.';
              |es_ES = 'No se puede realizar la operación porque el subsistema ""%1"" no está implementado en la configuración.
              |Este subsistema es la entrada a la biblioteca del contenido de la tecnología de servicio, que tienen que incorporarse por separado al contenido de la configuración.
              |Revisar si el subsistema ""%1"" existe y está implementado de forma correcta.';
              |es_CO = 'No se puede realizar la operación porque el subsistema ""%1"" no está implementado en la configuración.
              |Este subsistema es la entrada a la biblioteca del contenido de la tecnología de servicio, que tienen que incorporarse por separado al contenido de la configuración.
              |Revisar si el subsistema ""%1"" existe y está implementado de forma correcta.';
              |tr = 'Bir nedenle işlem gerçekleştirilemiyor - yapılandırmada ""%1"" alt sistemi uygulanmadı. 
              |Bu alt sistem, yapılandırmanın bir parçası olarak ayrı ayrı uygulanması gereken hizmet teknolojisi kütüphanesinin bir parçası olarak gelir. 
              | ""%1"" Alt sistemin uygulanmasının kullanılabilirliğini ve doğruluğunu kontrol edin.';
              |it = 'Non è possibile completare l''operazione per il seguente motivo: nella configurazione non è implementata il sottosistema ""%1"". 
              | Tale sottosistema è fornito all''interno della libreria della tecnologia di servizio, la quale deve essere introdotta separatamente all''interno della configurazione. 
              |Verificare la presenza e la correttezza dell''inserimento del sottosistema ""%1"".';
              |de = 'Die Operation kann nicht ausgeführt werden, da das Subsystem ""%1"" in der Konfiguration nicht implementiert ist.
              |Dieses Untersystem wird in die Bibliothek des Servicetechnologieinhalts eingegeben, die separat in den Konfigurationsinhalt eingebettet werden sollte.
              |Prüfen Sie, ob das Subsystem ""%1"" existiert und korrekt implementiert ist.'"),
		SubsystemName);
	
EndProcedure

// Tries to execute a query in several attempts.
// Is used for reading fast-changing data outside a transaction.
// If it is called in a transaction, leads to an error.
//
// Parameters:
//  Query - Query - query to be executed.
//
// Returns:
//  QueryResult - query execution result.
//
Function ExecuteQueryOutsideTransaction(Val Query) Export
	
	If TransactionActive() Then
		Raise(NStr("ru = 'Транзакция активна. Выполнение запроса вне транзакции невозможно.'; en = 'Transaction is active. Cannot execute a query outside the transaction.'; pl = 'Transakcja jest aktywna. Nie można wykonać zapytania poza transakcją.';es_ES = 'Transacción activa. No se puede ejecutar una solicitud fuera de la transacción.';es_CO = 'Transacción activa. No se puede ejecutar una solicitud fuera de la transacción.';tr = 'İşlem aktif. İşlemin dışında bir sorgu yürütülemiyor.';it = 'Transazione è attiva. Non è possibile eseguire una query di fuori della transazione.';de = 'Die Transaktion ist aktiv. Eine Abfrage kann nicht außerhalb der Transaktion ausgeführt werden.'"));
	EndIf;
	
	AttemptCount = 0;
	
	Result = Undefined;
	While True Do
		Try
			Result = Query.Execute(); // Reading outside a transaction, the following error can occur:
			                                // Could not continue scan with NOLOCK due to data movement. In this case, attempt to read one more 
			                                // time.
			Break;
		Except
			AttemptCount = AttemptCount + 1;
			If AttemptCount = 5 Then
				Raise;
			EndIf;
		EndTry;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns XML presentation of the XDTO type.
//
// Parameters:
//  XDTOType - XDTOObjectType, XDTOValueType - XDTO type whose XML presentation will be retrieved.
//   XML presentation.
//
// Returns:
//  String - XML presentation of the XDTO type.
//
Function XDTOTypePresentation(XDTOType) Export
	
	Return XDTOSerializer.XMLString(New XMLExpandedName(XDTOType.NamespaceURI, XDTOType.Name))
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// Checking shared data.

// CheckSharedDataOnWrite event subscription handler.
//
Procedure CheckSharedObjectsOnWrite(Source, Cancel) Export
	
	// DataExchange.Import is not required.
	// Writing of unseparated data from the separated session is restricted.
	CheckSharedDataOnWrite(Source);
	
EndProcedure

// CheckSharedRecordSetOnWrite event subscription handler.
//
Procedure CheckSharedRecordsSetsOnWrite(Source, Cancel, Overwrite) Export
	
	// DataExchange.Import is not required.
	// Writing of unseparated data from the separated session is restricted.
	CheckSharedDataOnWrite(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handling auxiliary area data.

// Writes the value of a reference type separated with AuxiliaryDataSeparator switching the session 
// separator during the writing.
//
// Parameters:
//  AuxiliaryDataObject - object of a reference type or ObjectDeletion.
//
Procedure WriteAuxiliaryData(AuxiliaryDataObject) Export
	
	HandleAuxiliaryData(
		AuxiliaryDataObject,
		True,
		False);
	
EndProcedure

// Deletes the value of a reference type separated with AuxiliaryDataSeparator switching the session 
// separator during the writing.
//
// Parameters:
//  AuxiliaryDataObject - reference type value.
//
Procedure DeleteAuxiliaryData(AuxiliaryDataObject) Export
	
	HandleAuxiliaryData(
		AuxiliaryDataObject,
		False,
		True);
	
EndProcedure

// Creates the record key for the information register included in the DataAreaAuxiliaryData separator content.
//
// Parameters:
//  Manager - InformationRegisterManager, information register manager whose record key is created,
//    
//  KeyValues - Structure contains values used for filling record key properties.
//    Structure item names must correspond with the names of key fields.
//
// Returns: InformationRegisterRecordKey.
//
Function CreateAuxiliaryDataInformationRegisterRecordKey(Val Manager, Val KeyValues) Export
	
	varKey = Manager.CreateRecordKey(KeyValues);
	
	DataArea = Undefined;
	Separator = AuxiliaryDataSeparator();
	
	If KeyValues.Property(Separator, DataArea) Then
		
		If varKey[Separator] <> DataArea Then
			
			Object = XDTOSerializer.WriteXDTO(varKey);
			Object[Separator] = DataArea;
			varKey = XDTOSerializer.ReadXDTO(Object);
			
		EndIf;
		
	EndIf;
	
	Return varKey;
	
EndFunction

// For internal use.
//
Function DataAreaMainDataContent() Export
	Return Metadata.CommonAttributes.DataAreaMainData.Content;
EndFunction

// For internal use.
//
Function GetDataAreasQueryResult() Export
	Query = New Query();
	Query.Text = 
	"SELECT
	|	DataAreas.DataAreaAuxiliaryData AS DataArea
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)
	|ORDER BY
	|	DataArea";
	
	Result = Query.Execute();
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See JobQueueOverridable.OnDefineHandlerAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("SaaS.PrepareDataAreaForUsage");
	
	NameAndAliasMap.Insert("SaaS.ClearDataArea");
	
EndProcedure

// See JobQueueOverridable.OnDetermineScheduledJobsUsage. 
Procedure OnDetermineScheduledJobsUsage(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "DataAreaMaintenance";
	NewRow.Use       = True;
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Import to the currency classifier is denied.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.DataAreaJobQueue.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.DataAreaKey);
	Types.Add(Metadata.InformationRegisters.DataAreas);
	
EndProcedure

// See SaaSOverridable.OnEnableDataSeparation. 
Procedure OnEnableSeparationByDataAreas() Export
	
	CheckConfigurationUsageAvailabilitySaaS();
	
	SaaSOverridable.OnEnableSeparationByDataAreas();
	
EndProcedure

// See SuppliedDataOverridable.GetSuppliedDataHandlers. 
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	RegisterSuppliedDataHandlers(Handlers);
	
EndProcedure

// Verifying the safe mode of data separation.
// To be called only from the session module.
//
Procedure EnablingDataSeparationSafeModeOnCheck() Export
	
	If SafeMode() = False
		AND DataSeparationEnabled()
		AND SeparatedDataUsageAvailable()
		AND NOT SessionWithoutSeparators() Then
		
		If NOT DataSeparationSafeMode(AuxiliaryDataSeparator()) Then
			
			SetDataSeparationSafeMode(AuxiliaryDataSeparator(), True);
			
		EndIf;
		
		If NOT DataSeparationSafeMode(MainDataSeparator()) Then
			
			SetDataSeparationSafeMode(MainDataSeparator(), True);
			
		EndIf;
	
	EndIf;
	
EndProcedure

// Checking for data area lock on start.
// To be called only from StandardSubsystemsServer.AddClientParametersOnStart(.
//
Procedure LockDataAreaOnStartOnCheck(ErrorDescription) Export
	
	If DataSeparationEnabled()
			AND SeparatedDataUsageAvailable()
			AND DataAreaLocked(SessionSeparatorValue()) Then
		
		ErrorDescription =
			NStr("ru = 'Запуск приложения временно недоступен.
			           |Выполняются регламентные операции по обслуживанию приложения.
			           |
			           |Попробуйте запустить приложение через несколько минут.'; 
			           |en = 'Running the application is temporary unavailable.
			           |Regulatory service operations are currently running.
			           |
			           |Try to run the application after a few minutes.'; 
			           |pl = 'Uruchomienie aplikacji jest chwilowo niedostępne.
			           | Trwają zaplanowane operacje obsługi aplikacji.
			           |
			           |Spróbuj uruchomić aplikację za kilka minut.';
			           |es_ES = 'El lanzamiento de la aplicación temporalmente no se encuentra disponible.
			           |Operaciones programadas del mantenimiento de la aplicación están en progreso.
			           |
			           |Intentar iniciar la aplicación en algunos minutos.';
			           |es_CO = 'El lanzamiento de la aplicación temporalmente no se encuentra disponible.
			           |Operaciones programadas del mantenimiento de la aplicación están en progreso.
			           |
			           |Intentar iniciar la aplicación en algunos minutos.';
			           |tr = 'Uygulamayı geçici olarak çalıştırılamıyor. 
			           | Rutin uygulama bakım işlemleri gerçekleştirilir. 
			           |
			           |Birkaç dakika içinde uygulamayı çalıştırmayı deneyin.';
			           |it = 'L''avvio dell''applicazione non è temporaneamente disponibile.
			           |Sono in corso le operazioni programmate di servizio.
			           |
			           |Riprova ad avviare l''applicazione tra qualche minuto.';
			           |de = 'Der Start der Anwendung ist vorübergehend nicht verfügbar.
			           |Der reguläre Servicebetrieb läuft derzeit.
			           |
			           |Versuchen Sie, die Anwendung in einigen Minuten zu starten.'");
		
	EndIf;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.31";
	Handler.Procedure = "SaaS.MoveDataAreas";
	Handler.SharedData = True;
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 99;
	Handler.ExclusiveMode = True;
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "SaaS.DisableUserSeparationByInternalDataSeparator";
	Handler.SharedData = True;
	Handler.ExclusiveMode = True;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "SaaS.CheckSeparatorsOnUpdate";
	Handler.SharedData = True;
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 99;
	Handler.ExclusiveMode = False;
	
	If DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "SaaS.CheckConfigurationUsageAvailabilitySaaS";
		Handler.SharedData = True;
		Handler.ExecuteInMandatoryGroup = True;
		Handler.Priority = 99;
		Handler.ExclusiveMode = False;
		
	EndIf;
	
	If DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.Version = "2.2.4.9";
		Handler.Procedure = "SaaS.MoveDataAreaActivityRating";
		Handler.SharedData = True;
		Handler.ExecuteInMandatoryGroup = True;
		Handler.ExclusiveMode = True;
		
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	OnAddClientParameters(Parameters);
	
EndProcedure

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	If NOT DataSeparationEnabled()
		OR NOT SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreaPresentation.Value AS Presentation
	|FROM
	|	Constant.DataAreaPresentation AS DataAreaPresentation
	|WHERE
	|	DataAreaPresentation.DataAreaAuxiliaryData = &DataAreaAuxiliaryData";
	SetPrivilegedMode(True);
	Query.SetParameter("DataAreaAuxiliaryData", SessionSeparatorValue());
	// Considering that the data is unchangeable.
	Result = Query.Execute();
	SetPrivilegedMode(False);
	If NOT Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		If SessionWithoutSeparators() Then
			Parameters.Insert("DataAreaPresentation", 
				Format(SessionSeparatorValue(), "NZ=0; NG=") +  " - " + Selection.Presentation);
		ElsIf NOT IsBlankString(Selection.Presentation) Then
			Parameters.Insert("DataAreaPresentation", Selection.Presentation);
		EndIf;
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.AfterDataImport. 
Procedure AfterImportData(Container) Export
	
	UsersInternal.AfterImportData(Container);
	
	If Common.SubsystemExists("StandardSubsystems.TotalsAndAggregatesManagement") Then
		
		ModuleTotalsAndAggregatesInternal = Common.CommonModule("TotalsAndAggregatesManagementIntenal");
		ModuleTotalsAndAggregatesInternal.CalculateTotals();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Returns the full path to the temporary file directory.
//
// Returns:
// String - full path to the temporary file directory.
//
Function GetCommonTempFilesDir()
	
	SetPrivilegedMode(True);
	
	SystemInfo = New SystemInfo;
	ServerPlatformType = SystemInfo.PlatformType;
	
	If ServerPlatformType = PlatformType.Linux_x86
		OR ServerPlatformType = PlatformType.Linux_x86_64 Then
		
		CommonTempDirectory = Constants.FileExchangeDirectorySaaSLinux.Get();
		PathSeparator = "/";
	Else
		CommonTempDirectory = Constants.FileExchangeDirectorySaaS.Get();
		PathSeparator = "\";
	EndIf;
	
	If IsBlankString(CommonTempDirectory) Then
		CommonTempDirectory = TrimAll(TempFilesDir());
	Else
		CommonTempDirectory = TrimAll(CommonTempDirectory);
	EndIf;
	
	If Not StrEndsWith(CommonTempDirectory, PathSeparator) Then
		CommonTempDirectory = CommonTempDirectory + PathSeparator;
	EndIf;
	
	Return CommonTempDirectory;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Preparing data areas

// Updates data area statuses in the DataArea register, sends a message to the service manager.
//
// Parameters:
//  RecordManager - InformationRegisters.DataAreas.RecordManager
//  PreparationResult - string, "Success", "ConversionRequired", "FatalError",
//    "DeletionError", or "AreaDeleted"
//  ErrorMessage - string.
//
Procedure ChangeAreaStatusAndInformManager(Val RecordManager, Val PreparationResult, Val ErrorMessage)
	
	ManagerCopy = InformationRegisters.DataAreas.CreateRecordManager();
	FillPropertyValues(ManagerCopy, RecordManager);
	RecordManager = ManagerCopy;

	IncludeErrorMessage = False;
	
	ModuleToCall = Common.CommonModule("RemoteAdministrationControlMessagesInterface");
	If PreparationResult = "Success" Then
		RecordManager.Status = Enums.DataAreaStatuses.Used;
		MessageType = ModuleToCall.MessageDataAreaPrepared();
	ElsIf PreparationResult = "ConversionRequired" Then
		RecordManager.Status = Enums.DataAreaStatuses.ImportFromFile;
		MessageType = ModuleToCall.MessageErrorPreparingDataAreaConversionRequired();
	ElsIf PreparationResult = "AreaDeleted" Then
		RecordManager.Status = Enums.DataAreaStatuses.Deleted;
		MessageType = ModuleToCall.MessageDataAreaDeleted();
	ElsIf PreparationResult = "FatalError" Then
		WriteLogEvent(EventLogEventDataAreaPreparation(), 
			EventLogLevel.Error, , , ErrorMessage);
		RecordManager.ProcessingError = True;
		MessageType = ModuleToCall.MessageErrorPreparingDataArea();
		IncludeErrorMessage = True;
	ElsIf PreparationResult = "DeletionError" Then
		RecordManager.ProcessingError = True;
		MessageType = ModuleToCall.MessageErrorDeletingDataArea();
		IncludeErrorMessage = True;
	Else
		Raise NStr("ru = 'Неожиданный код возврата'; en = 'Unexpected return code'; pl = 'Nieoczekiwany kod powrotu';es_ES = 'Código de vuelta inesperado';es_CO = 'Código de vuelta inesperado';tr = 'Beklenmeyen geri dönüş kodu';it = 'Codice di ritorno imprevisto';de = 'Unerwarteter Rückgabecode'");
	EndIf;
	
	// Send data area ready message to the service manager.
	Message = MessagesSaaS.NewMessage(MessageType);
	Message.Body.Zone = RecordManager.DataAreaAuxiliaryData;
	If IncludeErrorMessage Then
		Message.Body.ErrorDescription = ErrorMessage;
	EndIf;

	BeginTransaction();
	Try
		MessagesSaaS.SendMessage(
			Message,
			ServiceManagerEndpoint());
		
		RecordManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Imports data to the data area from the custom data.
// 
// Parameters:
//   DataArea - number of the data area to be filled.
//   ExportFileID - initial data file ID.
//   ErrorMessage - string, a returned error details.
//
// Returns:
//  String - "ConversionRequired", "Success", or "FatalError.
//
Function PrepareDataAreaForUsageFromExport(Val DataArea, Val ExportFileID, ErrorMessage)
	
	ExportFileName = GetFileFromServiceManagerStorage(ExportFileID);
	
	If ExportFileName = Undefined Then
		
		ErrorMessage = NStr("ru = 'Нет файла начальных данных для области'; en = 'No initial data file for the data area'; pl = 'Brak początkowego pliku informacyjnego dla obszaru';es_ES = 'No hay un archivo de la información inicial para el área';es_CO = 'No hay un archivo de la información inicial para el área';tr = 'Alan için hiçbir başlangıç veri dosyası yok';it = 'Il file dei dati iniziali dell''area non è presente';de = 'Keine initiale Infodatei für den Bereich'");
		
		Return "FatalError";
	EndIf;
	
	If Not Common.SubsystemExists("CloudTechnology.SaaS.ExportImportDataAreas") Then
		
		RaiseNoCTLSubsystemException("CloudTechnology.SaaS.ExportImportDataAreas");
		
	EndIf;
	
	ModuleExportImportDataAreas = Common.CommonModule("ExportImportDataAreas");
	
	If Not ModuleExportImportDataAreas.DataInArchiveCompatibleWithCurrentConfiguration(ExportFileName) Then
		Result = "ConversionRequired";
	Else
		
		ModuleExportImportDataAreas.ImportCurrentDataAreaFromArchive(ExportFileName);
		Result = "Success";
		
	EndIf;
	
	Try
		DeleteFiles(ExportFileName);
	Except
		WriteLogEvent(EventLogEventDataAreaPreparation(), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for determining types of metadata objects by full metadata object names.
// 

Function CheckMetadataObjectTypeByFullName(Val FullName, Val CurrentLocalization, Val EnglishLocalization, Val SubstringPosition = 0)
	
	Substrings = StrSplit(FullName, ".");
	If Substrings.Count() > SubstringPosition Then
		TypeName = Substrings.Get(SubstringPosition);
		Return TypeName = CurrentLocalization OR TypeName = EnglishLocalization;
	Else
		Return False;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Processing infobase parameters

// Returns an empty table of infobase parameters.
//
Function GetBlankIBParametersTable()
	
	Result = New ValueTable;
	Result.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Details", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("ReadProhibition", New TypeDescription("Boolean"));
	Result.Columns.Add("WriteProhibition", New TypeDescription("Boolean"));
	Result.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File operations

// Adds a file to the service manager storage.
//
// Parameters:
// AddressDataFile - String/BinaryData/File - address of the temporary storage/file data/file.
// ConnectionParameters - Structure:
//							- URL - String - the service URL. Mandatory to be filled in.
//							- UserName - String - service user name.
//							- Password - String - service user password.
// FileName - String - stored file name.
//		
// Returns:
// UUID - file ID in the storage.
//
Function PutFileInStorage(Val AddressDataFile, Val ConnectionParameters, Val FileName = "")
	
	DeleteTemporaryFile = False;
	ExecutionStarted = CurrentUniversalDate();
	
	ProxyDetails = FileTransferServiceProxyDetails(ConnectionParameters);
	
	Details = GetDataFileName(AddressDataFile, FileName);
	
	If IsBlankString(Details.Name) Then
		
		Details.Name = GetTempFileName();
		DeleteTemporaryFile = True;
		
	EndIf;
	
	FIleProperties = New File(Details.Name);
	
	ExchangeOverFS = CanTransferThroughFSToServer(ProxyDetails.Proxy, ProxyDetails.HasSecondVersionSupport);
	
	If ExchangeOverFS Then
		
		// Save data to file.
		CommonDirectory = GetCommonTempFilesDir();
		DestinationFile = New File(CommonDirectory + FIleProperties.Name);
		If DestinationFile.Exist() Then
			// It's a single file. It can be read directly on the server.
			If FIleProperties.FullName = DestinationFile.FullName Then
				Result = ProxyDetails.Proxy.ReadFileFromFS(DestinationFile.Name, FIleProperties.Name);
				SourceFileSize = DestinationFile.Size();
				WriteFileStorageEventToLog(
					NStr("ru = 'Помещение'; en = 'Putting'; pl = 'Lokal';es_ES = 'Local';es_CO = 'Local';tr = 'Mekan';it = 'Posizionamento';de = 'Raum'", CommonClientServer.DefaultLanguageCode()),
					Result,
					SourceFileSize,
					CurrentUniversalDate() - ExecutionStarted,
					ExchangeOverFS);
				Return Result;
				// Cannot be deleted because it is a source file too.
			EndIf;
			// Source and destination are different files. Specifying a unique name for the destination file to prevent files from other sessions from deletion.
			NewID = New UUID;
			DestinationFile = New File(CommonDirectory + NewID + FIleProperties.Extension);
		EndIf;
		
		Try
			If Details.Data = Undefined Then
				FileCopy(FIleProperties.FullName, DestinationFile.FullName);
			Else
				Details.Data.Write(DestinationFile.FullName);
			EndIf;
			Result = ProxyDetails.Proxy.ReadFileFromFS(DestinationFile.Name, FIleProperties.Name);
			SourceFileSize = DestinationFile.Size();
			WriteFileStorageEventToLog(
				NStr("ru = 'Помещение'; en = 'Putting'; pl = 'Lokal';es_ES = 'Local';es_CO = 'Local';tr = 'Mekan';it = 'Posizionamento';de = 'Raum'", CommonClientServer.DefaultLanguageCode()),
				Result,
				SourceFileSize,
				CurrentUniversalDate() - ExecutionStarted,
				ExchangeOverFS);
		Except
			WriteLogEvent(EventLogEventAddingFileExchangeThroughFS(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			ExchangeOverFS = False;
		EndTry;
		
		DeleteTempFiles(DestinationFile.FullName);
		If DeleteTemporaryFile Then
			DeleteTempFiles(Details.Name)
		EndIf;
		
	EndIf; // ExchangeOverFS
		
	If NOT ExchangeOverFS Then
		
		If Details.Data = Undefined Then
			
			If FIleProperties.Exist() Then
				
				BuildDirectory = Undefined;
				FullFileName = FIleProperties.FullName;
				
			Else
				
				Raise(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Добавление файла в хранилище. Не найден файл %1.'; en = 'Add file to the storage. File %1 not found.'; pl = 'Dodaj plik do pamięci. Nie znaleziono pliku %1.';es_ES = 'Añadir el archivo al almacenamiento. Archivo %1 no encontrado.';es_CO = 'Añadir el archivo al almacenamiento. Archivo %1 no encontrado.';tr = 'Dosyayı depolama alanına ekle. Dosya %1 bulunamadı.';it = 'Aggiungere file per l''archiviazione. Il file %1 non trovato.';de = 'Fügen Sie dem Speicher eine Datei hinzu. Datei %1 nicht gefunden.'"),
					FIleProperties.FullName));
					
			EndIf;
				
		Else
			
			Try
				
				BuildDirectory = CreateAssemblyDirectory();
				FullFileName = BuildDirectory + FIleProperties.Name;
				Details.Data.Write(FullFileName);
				
			Except
				
				DeleteTempFiles(BuildDirectory);
				Raise;
				
			EndTry;
			
		EndIf;
		
		// Compress file.
		Try
			
			ArchiveFileName = GetTempFileName("zip");
			Archiver = New ZipFileWriter(ArchiveFileName,,,, ZIPCompressionLevel.Minimum);
			Archiver.Add(FullFileName);
			Archiver.Write();
			
		Except
			
			If DeleteTemporaryFile Then
				
				DeleteTempFiles(Details.Name);
				
			EndIf;
			
			DeleteTempFiles(ArchiveFileName);

			If ValueIsFilled(BuildDirectory) Then
				
				DeleteTempFiles(BuildDirectory);
				
			EndIf;
			
			Raise;
				
		EndTry;
		
		If DeleteTemporaryFile Then
			
			DeleteTempFiles(Details.Name);
			
		EndIf;
		
		If ValueIsFilled(BuildDirectory) Then
			
			DeleteTempFiles(BuildDirectory);
			
		EndIf;
		
		FileTransferBlockSize = GetFileTransferBlockSize() * 1024 * 1024;
		TransferID = New UUID;
		
		ArchiveFile = New File(ArchiveFileName);
		ArchiveFileSize = ArchiveFile.Size();
		
		PartCount = Round((ArchiveFileSize / FileTransferBlockSize) + 0.5, 0, RoundMode.Round15as10);
		
		ReaderStream = Undefined;
		
		Try
			
			ReaderStream = FileStreams.OpenForRead(ArchiveFileName, FileTransferBlockSize);
			ReaderStream.Seek(0, PositionInStream.Begin);
			
			PartNumber = 0;
			
			While ReaderStream.CurrentPosition() < ArchiveFileSize - 1 Do
				
				PartNumber = PartNumber + 1;
				Buffer = New BinaryDataBuffer(Min(FileTransferBlockSize, ArchiveFileSize - ReaderStream.CurrentPosition()));
				ReaderStream.Read(Buffer, 0, Buffer.Size);
				
				AttemptCount = 10;
				
				For AttemptNumber = 1 To AttemptCount Do
				
					Try
						
						If ProxyDetails.HasSecondVersionSupport Then
							
							ProxyDetails.Proxy.PutFilePart(TransferID, PartNumber, GetBinaryDataFromBinaryDataBuffer(Buffer), PartCount);
							
						Else // 1st version.
							
							ProxyDetails.Proxy.PutFilePart(TransferID, PartNumber, GetBinaryDataFromBinaryDataBuffer(Buffer));
							
						EndIf;
						
						Break;
						
					Except
						
						If AttemptNumber = AttemptCount Then
							
							Raise;
							
						EndIf;
						
					EndTry;
					
				EndDo;
				
			EndDo;
			
		Except
			
			If ReaderStream <> Undefined Then
				
				ReaderStream.Close();
				
			EndIf;
			
			ExceptionDetails = ErrorDescription();
			
			DeleteTempFiles(ArchiveFileName);
			
			Try
				
				ProxyDetails.Proxy.ReleaseFile(TransferID);
				
			Except
				
				ExceptionDetails = ExceptionDetails + Chars.LF + ErrorDescription();
				
			EndTry;
			
			Raise ExceptionDetails;
			
		EndTry;
		
		ReaderStream.Close();
		DeleteTempFiles(ArchiveFileName);
		
		If ProxyDetails.HasSecondVersionSupport Then
			
			Result = ProxyDetails.Proxy.SaveFileFromParts(TransferID, PartCount);
			
		Else // 1st version.
			
			Result = Undefined;
			ProxyDetails.Proxy.SaveFileFromParts(TransferID, PartCount, Result);
			
		EndIf;
		
		WriteFileStorageEventToLog(
			NStr("ru = 'Помещение'; en = 'Putting'; pl = 'Lokal';es_ES = 'Local';es_CO = 'Local';tr = 'Mekan';it = 'Posizionamento';de = 'Raum'", CommonClientServer.DefaultLanguageCode()),
			Result,
			SourceFileSize,
			CurrentUniversalDate() - ExecutionStarted,
			ExchangeOverFS);
		
	EndIf; // Not ExchangeOverFS
	
	Return Result;
	
EndFunction

// Returns a structure with a name and data of the file by the address in the temporary storage / 
// details in the File object / binary data.
//
// Parameters:
//	AddressDataFile - String/BinaryData/File - address of the file data storage/file data/file.
//	FileName - String.
//		
// Returns:
// Structure:
//   Data - BinaryData - file data.
//   Name - String - a file name.
//
Function GetDataFileName(Val AddressDataFile, Val FileName = "")
	
	If TypeOf(AddressDataFile) = Type("String") Then // Address of the data file in the temporary storage.
		If IsBlankString(AddressDataFile) Then
			Raise(NStr("ru = 'Неверный адрес хранилища.'; en = 'Invalid storage address.'; pl = 'Błędny adres pamięci.';es_ES = 'Dirección de almacenamiento inválida.';es_CO = 'Dirección de almacenamiento inválida.';tr = 'Geçersiz depolama alanı adresi.';it = 'Indirizzo di memoria non è corretto.';de = 'Ungültige Speicheradresse.'"));
		EndIf;
		FileData = GetFromTempStorage(AddressDataFile);
	ElsIf TypeOf(AddressDataFile) = Type("File") Then // Object of the File type.
		If Not AddressDataFile.Exist() Then
			Raise(NStr("ru = 'Файл не найден.'; en = 'File not found.'; pl = 'Nie znaleziono pliku.';es_ES = 'Archivo no encontrado.';es_CO = 'Archivo no encontrado.';tr = 'Dosya bulunamadı.';it = 'File non trovato.';de = 'Die Datei wurde nicht gefunden.'"));
		EndIf;
		FileData = Undefined;
		FileName = AddressDataFile.FullName;
	ElsIf TypeOf(AddressDataFile) = Type("BinaryData") Then // File data.
		FileData = AddressDataFile;
	Else
		Raise(NStr("ru = 'Неверный тип данных'; en = 'Invalid data type'; pl = 'Błędny typ danych';es_ES = 'Tipo de datos inválido';es_CO = 'Tipo de datos inválido';tr = 'Geçersiz veri türü';it = 'Tipo di dati non corretto';de = 'Ungültiger Datentyp'"));
	EndIf;
	
	Return New Structure("Data, Name", FileData, FileName);
	
EndFunction

// Checks whether file transfer from server to client through the file system is possible.
//
// Parameters:
// Proxy - WSProxy - FilesTransfer* service proxy.
// HasVersion2Support - Boolean.
//
// Returns:
// Boolean.
//
Function CanPassViaFSFromServer(Val Proxy, Val HasSecondVersionSupport)
	
	If Not HasSecondVersionSupport Then
		Return False;
	EndIf;
	
	FileName = Proxy.WriteTestFile();
	If FileName = "" Then 
		Return False;
	EndIf;
	
	Result = ReadTestFile(FileName);
	
	Proxy.DeleteTestFile(FileName);
	
	Return Result;
	
EndFunction

// Checks whether file transfer from client to server through the file system is possible.
//
// Parameters:
// Proxy - WSProxy - FilesTransfer* service proxy.
// HasVersion2Support - Boolean.
//
// Returns:
// Boolean.
//
Function CanTransferThroughFSToServer(Val Proxy, Val HasSecondVersionSupport)
	
	If Not HasSecondVersionSupport Then
		Return False;
	EndIf;
	
	FileName = WriteTestFile();
	If FileName = "" Then 
		Return False;
	EndIf;
	
	Result = Proxy.ReadTestFile(FileName);
	
	FullFileName = GetCommonTempFilesDir() + FileName;
	DeleteTempFiles(FullFileName);
	
	Return Result;
	
EndFunction

// Create directory with a unique name to contain parts of the separated file.
//
// Returns:
// String - Directory name.
//
Function CreateAssemblyDirectory()
	
	BuildDirectory = GetTempFileName();
	CreateDirectory(BuildDirectory);
	Return BuildDirectory + GetPathSeparator();
	
EndFunction

// Reads the test file from disk, comparing the content and name that must match.
// The calling side must delete this file.
//
// Parameters:
// FileName - String - without a path.
//
// Returns:
// Boolean - True if the file is successfully read and the content match its name.
//
Function ReadTestFile(Val FileName)
	
	FIleProperties = New File(GetCommonTempFilesDir() + FileName);
	If FIleProperties.Exist() Then
		Text = New TextReader(FIleProperties.FullName, TextEncoding.ANSI);
		TestID = Text.Read();
		Text.Close();
		Return TestID = FIleProperties.BaseName;
	Else
		Return False;
	EndIf;
	
EndFunction

// Creates a blank structure of a necessary format.
//
// Returns:
// Structure:
//   Name - String - file name in the storage.
//   Data - BinaryData - file data.
// 	 FullName - String - file name with its path.
//
Function CreateFileDetails()
	
	FileDetails = New Structure;
	FileDetails.Insert("Name");
	FileDetails.Insert("Data");
	FileDetails.Insert("FullName");
	FileDetails.Insert("RequiredParameters", "Name"); // Mandatory parameters.
	Return FileDetails;
	
EndFunction

// Retrieves the WSProxy object of the Web service specified by the base name.
//
// Parameters:
// ConnectionParameters - Structure:
//							- URL - String - the service URL. Mandatory to be filled in.
//							- UserName - String - service user name.
//							- Password - String - service user password.
// Returns:
//  Structure
//   Proxy - WSProxy
//   HasVersion2Support - Boolean.
//
Function FileTransferServiceProxyDetails(Val ConnectionParameters)
	
	BaseServiceName = "FilesTransfer";
	
	SupportedVersionArray = Common.GetInterfaceVersions(ConnectionParameters, "FileTransferService");
	If SupportedVersionArray.Find("1.0.2.1") = Undefined Then
		HasSecondVersionSupport = False;
		InterfaceVersion = "1.0.1.1"
	Else
		HasSecondVersionSupport = True;
		InterfaceVersion = "1.0.2.1";
	EndIf;
	
	If ConnectionParameters.Property("UserName")
		AND ValueIsFilled(ConnectionParameters.UserName) Then
		
		Username = ConnectionParameters.UserName;
		UserPassword = ConnectionParameters.Password;
	Else
		Username = Undefined;
		UserPassword = Undefined;
	EndIf;
	
	If InterfaceVersion = Undefined Or InterfaceVersion = "1.0.1.1" Then // 1st version.
		ServiceName = BaseServiceName;
	Else // Version 2 and later.
		ServiceName = BaseServiceName + "_" + StrReplace(InterfaceVersion, ".", "_");
	EndIf;
	
	ServiceAddress = ConnectionParameters.URL + StringFunctionsClientServer.SubstituteParametersToString("/ws/%1?wsdl", ServiceName);
	
	ConnectionParameters = Common.WSProxyConnectionParameters();
	ConnectionParameters.WSDLAddress = ServiceAddress;
	ConnectionParameters.NamespaceURI = "http://www.1c.ru/SaaS/1.0/WS";
	ConnectionParameters.ServiceName = ServiceName;
	ConnectionParameters.UserName = Username;
	ConnectionParameters.Password = UserPassword;
	ConnectionParameters.Timeout = 600;
	Proxy = Common.CreateWSProxy(ConnectionParameters);
	
	Return New Structure("Proxy, HasSecondVersionSupport", Proxy, HasSecondVersionSupport);
		
EndFunction

Procedure WriteFileStorageEventToLog(Val Event,
	Val FileId, Val Size, Val Duration, Val TransferThroughFileSystem)
	
	EventData = New Structure;
	EventData.Insert("FileId", FileId);
	EventData.Insert("Size", Size);
	EventData.Insert("Duration", Duration);
	
	If TransferThroughFileSystem Then
		EventData.Insert("Transport", "file");
	Else
		EventData.Insert("Transport", "ws");
	EndIf;
	
	WriteLogEvent(
		NStr("ru = 'Хранилище файлов'; en = 'File storage'; pl = 'Przechowywanie plików';es_ES = 'Almacenamiento de archivos';es_CO = 'Almacenamiento de archivos';tr = 'Dosya depolama';it = 'Archiviazione di file';de = 'Dateispeicher'", CommonClientServer.DefaultLanguageCode()) + "." + Event,
		EventLogLevel.Information,
		,
		,
		Common.ValueToXMLString(EventData));
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Temporary files

// Delete file(s) from disk.
// If a mask with a path is passed as the file name, it is split to the path and the mask.
//
Procedure DeleteTempFiles(Val FileName)
	
	Try
		If StrEndsWith(FileName, "*") Then // Mask.
			Index = StrFind(FileName, GetPathSeparator(), SearchDirection.FromEnd);
			If Index > 0 Then
				PathToFile = Left(FileName, Index - 1);
				FileMask = Mid(FileName, Index + 1);
				If FindFiles(PathToFile, FileMask, False).Count() > 0 Then
					DeleteFiles(PathToFile, FileMask);
				EndIf;
			EndIf;
		Else
			FIleProperties = New File(FileName);
			If FIleProperties.Exist() Then
				FIleProperties.SetReadOnly(False); // Clearing the attribute.
				DeleteFiles(FIleProperties.FullName);
			EndIf;
		EndIf;
	Except
		WriteLogEvent(TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Serializing

Function WriteValueToString(Val Value)
	
	Record = New XMLWriter;
	Record.SetString();
	
	If TypeOf(Value) = Type("XDTODataObject") Then
		XDTOFactory.WriteXML(Record, Value, , , , XMLTypeAssignment.Explicit);
	Else
		XDTOSerializer.WriteXML(Record, Value, XMLTypeAssignment.Explicit);
	EndIf;
	
	Return Record.Close();
		
EndFunction

// Indicates whether this type is serialized.
//
// Parameters:
// StructuralType - Type.
//
// Returns:
// Boolean.
//
Function StructuralTypeToSerialize(StructuralType);
	
	TypeToSerializeArray = SaaSCached.StructuralTypesToSerialize();
	
	For Each TypeToSerialize In TypeToSerializeArray Do 
		If StructuralType = TypeToSerialize Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
		
EndFunction

// Receives XDTO presentation of structural type object.
//
// Parameters:
// StructuralTypeValue - Array, Structure, Map, or their fixed analogs.
//
// Returns:
// Structural XDTO Object - XDTO - presentation of structural type object.
//
Function StructuralObjectToXDTODataObject(Val StructuralTypeValue)
	
	StructuralType = TypeOf(StructuralTypeValue);
	
	If Not StructuralTypeToSerialize(StructuralType) Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Тип %1 не является структурным или его сериализация в настоящее время не поддерживается.'; en = 'Type ""%1"" is not structural or currently its serialization is not supported.'; pl = 'Typ ""%1"" nie jest strukturalny lub obecnie jego serializacja nie jest obsługiwana.';es_ES = 'Tipo ""%1"" no es estructural, o su serialización temporalmente no está admitida.';es_CO = 'Tipo ""%1"" no es estructural, o su serialización temporalmente no está admitida.';tr = '""%1"" türü yapısal değil veya şu andaki serileştirme desteklenmiyor.';it = '%1 non è un tipo uno strutturale o la sua serializzazione non è attualmente supportato.';de = 'Typ ""%1"" ist nicht strukturell oder seine Serialisierung wird derzeit nicht unterstützt.'"),
			StructuralType);
		Raise(ErrorMessage);
	EndIf;
	
	XMLValueType = XDTOSerializer.XMLTypeOf(StructuralTypeValue);
	StructureType = XDTOFactory.Type(XMLValueType);
	XDTOStructure = XDTOFactory.Create(StructureType);
	
	// Iterating allowed structural types.
	
	If StructuralType = Type("Structure") Or StructuralType = Type("FixedStructure") Then
		
		PropertyType = StructureType.Properties.Get("Property").Type;
		
		For Each KeyAndValue In StructuralTypeValue Do
			Property = XDTOFactory.Create(PropertyType);
			Property.name = KeyAndValue.Key;
			Property.Value = TypeValueToXDTOValue(KeyAndValue.Value);
			XDTOStructure.Property.Add(Property);
		EndDo;
		
	ElsIf StructuralType = Type("Array") Or StructuralType = Type("FixedArray") Then 
		
		For Each ItemValue In StructuralTypeValue Do
			XDTOStructure.Value.Add(TypeValueToXDTOValue(ItemValue));
		EndDo;
		
	ElsIf StructuralType = Type("Map") Or StructuralType = Type("FixedMap") Then
		
		For Each KeyAndValue In StructuralTypeValue Do
			XDTOStructure.pair.Add(StructuralObjectToXDTODataObject(KeyAndValue));
		EndDo;
	
	ElsIf StructuralType = Type("KeyAndValue")	Then	
		
		XDTOStructure.key = TypeValueToXDTOValue(StructuralTypeValue.Key);
		XDTOStructure.value = TypeValueToXDTOValue(StructuralTypeValue.Value);
		
	ElsIf StructuralType = Type("ValueTable") Then
		
		XDTOVTColumnType = StructureType.Properties.Get("column").Type;
		
		For Each Column In StructuralTypeValue.Columns Do
			
			XDTOColumn = XDTOFactory.Create(XDTOVTColumnType);
			
			XDTOColumn.Name = TypeValueToXDTOValue(Column.Name);
			XDTOColumn.ValueType = XDTOSerializer.WriteXDTO(Column.ValueType);
			XDTOColumn.Title = TypeValueToXDTOValue(Column.Title);
			XDTOColumn.Width = TypeValueToXDTOValue(Column.Width);
			
			XDTOStructure.column.Add(XDTOColumn);
			
		EndDo;
		
		XDTOTypeVTIndex = StructureType.Properties.Get("index").Type;
		
		For Each Index In StructuralTypeValue.Indexes Do
			
			XDTOIndex = XDTOFactory.Create(XDTOTypeVTIndex);
			
			For Each IndexField In Index Do
				XDTOIndex.column.Add(TypeValueToXDTOValue(IndexField));
			EndDo;
			
			XDTOStructure.index.Add(XDTOIndex);
			
		EndDo;
		
		XDTOTypeVTRow = StructureType.Properties.Get("row").Type;
		
		For Each SpecificationRow In StructuralTypeValue Do
			
			XDTORow = XDTOFactory.Create(XDTOTypeVTRow);
			
			For Each ColumnValue In SpecificationRow Do
				XDTORow.value.Add(TypeValueToXDTOValue(ColumnValue));
			EndDo;
			
			XDTOStructure.row.Add(XDTORow);
			
		EndDo;
		
	EndIf;
	
	Return XDTOStructure;
	
EndFunction

// Retrieves structural type object from XDTO object.
//
// Parameters:
// XDTODataObject - XDTODataObject.
//
// Returns:
// Structural type (Array, Structure, Map, or their fixed analogs).
//
Function XDTODataObjectToStructuralObject(XDTODataObject)
	
	XMLDataType = New XMLDataType(XDTODataObject.Type().Name, XDTODataObject.Type().NamespaceURI);
	If CanReadXMLDataType(XMLDataType) Then
		StructuralType = XDTOSerializer.FromXMLType(XMLDataType);
	Else
		Return XDTODataObject;
	EndIf;
	
	If StructuralType = Type("String") Then
		Return "";
	EndIf;
	
	If Not StructuralTypeToSerialize(StructuralType) Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Тип %1 не является структурным или его сериализация в настоящее время не поддерживается.'; en = 'Type ""%1"" is not structural or currently its serialization is not supported.'; pl = 'Typ ""%1"" nie jest strukturalny lub obecnie jego serializacja nie jest obsługiwana.';es_ES = 'Tipo ""%1"" no es estructural, o su serialización temporalmente no está admitida.';es_CO = 'Tipo ""%1"" no es estructural, o su serialización temporalmente no está admitida.';tr = '""%1"" türü yapısal değil veya şu andaki serileştirme desteklenmiyor.';it = '%1 non è un tipo uno strutturale o la sua serializzazione non è attualmente supportato.';de = 'Typ ""%1"" ist nicht strukturell oder seine Serialisierung wird derzeit nicht unterstützt.'"),
			StructuralType);
		Raise(ErrorMessage);
	EndIf;
	
	If StructuralType = Type("Structure")	Or StructuralType = Type("FixedStructure") Then
		
		StructuralObject = New Structure;
		
		For Each Property In XDTODataObject.Property Do
			StructuralObject.Insert(Property.name, XDTOValueToTypeValue(Property.Value));          
		EndDo;
		
		If StructuralType = Type("Structure") Then
			Return StructuralObject;
		Else 
			Return New FixedStructure(StructuralObject);
		EndIf;
		
	ElsIf StructuralType = Type("Array") Or StructuralType = Type("FixedArray") Then 
		
		StructuralObject = New Array;
		
		For Each ArrayElement In XDTODataObject.Value Do
			StructuralObject.Add(XDTOValueToTypeValue(ArrayElement));          
		EndDo;
		
		If StructuralType = Type("Array") Then
			Return StructuralObject;
		Else 
			Return New FixedArray(StructuralObject);
		EndIf;
		
	ElsIf StructuralType = Type("Map") Or StructuralType = Type("FixedMap") Then
		
		StructuralObject = New Map;
		
		For Each KeyAndValueXDTO In XDTODataObject.pair Do
			KeyAndValue = XDTODataObjectToStructuralObject(KeyAndValueXDTO);
			StructuralObject.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		
		If StructuralType = Type("Map") Then
			Return StructuralObject;
		Else 
			Return New FixedMap(StructuralObject);
		EndIf;
	
	ElsIf StructuralType = Type("KeyAndValue")	Then	
		
		StructuralObject = New Structure("Key, Value");
		StructuralObject.Key = XDTOValueToTypeValue(XDTODataObject.key);
		StructuralObject.Value = XDTOValueToTypeValue(XDTODataObject.value);
		
		Return StructuralObject;
		
	ElsIf StructuralType = Type("ValueTable") Then
		
		StructuralObject = New ValueTable;
		
		For Each Column In XDTODataObject.column Do
			
			StructuralObject.Columns.Add(
				XDTOValueToTypeValue(Column.Name), 
				XDTOSerializer.ReadXDTO(Column.ValueType), 
				XDTOValueToTypeValue(Column.Title), 
				XDTOValueToTypeValue(Column.Width));
				
		EndDo;
		For Each Index In XDTODataObject.index Do
			
			IndexString = "";
			For Each IndexField In Index.column Do
				IndexString = IndexString + IndexField + ", ";
			EndDo;
			IndexString = TrimAll(IndexString);
			If StrLen(IndexString) > 0 Then
				IndexString = Left(IndexString, StrLen(IndexString) - 1);
			EndIf;
			
			StructuralObject.Indexes.Add(IndexString);
		EndDo;
		For Each XDTORow In XDTODataObject.row Do
			
			SpecificationRow = StructuralObject.Add();
			
			ColumnCount = StructuralObject.Columns.Count();
			For Index = 0 To ColumnCount - 1 Do 
				SpecificationRow[StructuralObject.Columns[Index].Name] = XDTOValueToTypeValue(XDTORow.value[Index]);
			EndDo;
			
		EndDo;
		
		Return StructuralObject;
		
	EndIf;
	
EndFunction

Function CanReadXMLDataType(Val XMLDataType)
	
	Record = New XMLWriter;
	Record.SetString();
	Record.WriteStartElement("Dummy");
	Record.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	Record.WriteNamespaceMapping("ns1", XMLDataType.NamespaceURI);
	Record.WriteAttribute("xsi:type", "ns1:" + XMLDataType.TypeName);
	Record.WriteEndElement();
	
	Row = Record.Close();
	
	Read = New XMLReader;
	Read.SetString(Row);
	Read.MoveToContent();
	
	Return XDTOSerializer.CanReadXML(Read);
	
EndFunction

// Receives simple type value in the XDTO context.
//
// Parameters:
// TypeValue - Arbitrary type value.
//
// Returns:
// Arbitrary type.
//
Function TypeValueToXDTOValue(Val TypeValue)
	
	If TypeValue = Undefined
		Or TypeOf(TypeValue) = Type("XDTODataObject")
		Or TypeOf(TypeValue) = Type("XDTODataValue") Then
		
		Return TypeValue;
		
	Else
		
		If TypeOf(TypeValue) = Type("String") Then
			XDTOType = XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "string")
		Else
			XMLType = XDTOSerializer.XMLTypeOf(TypeValue);
			XDTOType = XDTOFactory.Type(XMLType);
		EndIf;
		
		If TypeOf(XDTOType) = Type("XDTOObjectType") Then // Structural type value.
			Return StructuralObjectToXDTODataObject(TypeValue);
		Else
			Return XDTOFactory.Create(XDTOType, TypeValue); // For example, UUID.
		EndIf;
		
	EndIf;
	
EndFunction

// Receives the platform analog of the XDTO type value.
//
// Parameters:
// XDTODataValue - Arbitrary XDTO type value.
//
// Returns:
// Arbitrary type.
//
Function XDTOValueToTypeValue(XDTOValue)
	
	If TypeOf(XDTOValue) = Type("XDTODataValue") Then
		Return XDTOValue.Value;
	ElsIf TypeOf(XDTOValue) = Type("XDTODataObject") Then
		Return XDTODataObjectToStructuralObject(XDTOValue);
	Else
		Return XDTOValue;
	EndIf;
	
EndFunction

// Fills the area with supplied data when preparing the area to use.
//
// Parameters:
//   DataArea - number of the data area to be filled.
//   ExportFileID - initial data file ID.
//   Option - initial data option.
//   UseMode - demo or production.
//
// Returns:
//  String - "Success" or "FatalError".
//
Function ImportDataAreaFromSuppliedData(Val DataArea, Val ExportFileID, Val Option, FatalErrorMessage)
	
	If NOT Users.IsFullUser(, True) Then
		Raise(NStr("ru = 'Недостаточно прав для выполнения операции'; en = 'Insufficient rights to perform the operation'; pl = 'Nie masz wystarczających uprawnień do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operación';es_CO = 'Insuficientes derechos para realizar la operación';tr = 'İşlem için gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausführen der Operation'"));
	EndIf;
	
	DataFileFound = False;
	
	Filter = New Array();
	Filter.Add(New Structure("Code, Value", "ConfigurationName", Metadata.Name));
	Filter.Add(New Structure("Code, Value", "ConfigurationVersion", Metadata.Version));
	Filter.Add(New Structure("Code, Value", "Variant", Option));
	Filter.Add(New Structure("Code, Value", "Mode", 
		?(Constants.InfobaseUsageMode.Get() 
			= Enums.InfobaseUsageModes.Demo, 
			"Demo", "Work")));

	Descriptor = SuppliedData.DescriptorSuppliedDataInCache(ExportFileID);
	If Descriptor <> Undefined Then
		If SuppliedData.CharacteristicsCoincide(Filter, Descriptor.Characteristics) Then
			PrototypeData = SuppliedData.SuppliedDataFromCache(ExportFileID);
			ExportFileName = GetTempFileName();
			PrototypeData.Write(ExportFileName);
			DataFileFound = True;
		Else
			FatalErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Указанный файл начальных данных не подходит для данной конфигурации.
					|Дескриптор файла: %1'; 
					|en = 'The specified file of initial data is invalid for this configuration.
					|File handle: %1'; 
					|pl = 'Określony plik danych źródłowych nie ma zastosowania dla tej konfiguracji.
					|Deskryptor pliku: %1';
					|es_ES = 'Archivo especificado de los datos iniciales no es aplicable para esta configuración.
					|Descriptor del archivo: %1';
					|es_CO = 'Archivo especificado de los datos iniciales no es aplicable para esta configuración.
					|Descriptor del archivo: %1';
					|tr = 'Bu konfigürasyon için belirtilen başlangıç verisi dosyası geçerli değildir.
					|Dosyanın tanımlayıcısı: %1';
					|it = 'Il file specificato di dati iniziali non è valido per questa configurazione.
					|Gestore file: %1';
					|de = 'Die angegebene Datei der Anfangsdaten ist für diese Konfiguration nicht anwendbar.
					|Deskriptor der Datei: %1'"),
				SuppliedData.GetDataDescription(Descriptor));
			Return "FatalError";
		EndIf;
	EndIf;
	
	If Not DataFileFound Then
	
		Descriptors = SuppliedData.SuppliedDataDescriptorsFromManager("DataAreaPrototype", Filter);
	
		If Descriptors.Descriptor.Count() = 0 Then
			FatalErrorMessage = 
			NStr("ru = 'В менеджере сервиса нет файла начальных данных для текущей версии конфигурации.'; en = 'The service manager has no initial data file for the current applied solution version .'; pl = 'Menedżer usług nie zawiera początkowego pliku danych dla bieżącej wersji konfiguracji.';es_ES = 'Gestor de servicio no incluye el archivo de los datos iniciales para la versión de la configuración actual.';es_CO = 'Gestor de servicio no incluye el archivo de los datos iniciales para la versión de la configuración actual.';tr = 'Servis yöneticisi mevcut yapılandırma sürümü için ilk veri dosyasını içermez.';it = 'Nel gestore del servizio non è presente il file contenente i dati iniziali dell''attuale versione della configurazione.';de = 'Der Service Manager enthält nicht die ursprüngliche Datendatei für die aktuelle Konfigurationsversion.'");
			Return "FatalError";
		EndIf;
		
		If Descriptors.Descriptor[0].FileGUID <> ExportFileID Then
			FatalErrorMessage = 
			NStr("ru = 'Файл начальных данных, имеющийся в менеджере сервиса, отличается от указанного в сообщении на подготовку области. Область не может быть подготовлена.'; en = 'The initial data file available in the service manager differs from the one specified in the message for the area preparation. Cannot prepare the area.'; pl = 'Początkowy plik danych dostępny w menedżerze usług różni się od podanego w komunikacie dla przygotowania obszaru. Nie można przygotować obszaru.';es_ES = 'Al archivo de los datos iniciales en el gestor de servicio es diferente de aquel especificado en el mensaje para la preparación del área. No se puede preparar el área.';es_CO = 'Al archivo de los datos iniciales en el gestor de servicio es diferente de aquel especificado en el mensaje para la preparación del área. No se puede preparar el área.';tr = 'Servis yöneticisinde bulunan ilk veri dosyası alan hazırlığı için mesajda belirtilenlerden farklıdır. Alanı hazırlayamıyor.';it = 'Il file di dati iniziale disponibile nel gestore servizi è diverso da quello specificato nel messaggio di preparazione per l''area. L''area non può essere preparata.';de = 'Die im Service Manager verfügbare Anfangsdaten unterscheiden sich von den in der Nachricht zur Bereichsvorbereitung angegebenen. Kann den Bereich nicht vorbereiten.'");
			Return "FatalError";
		EndIf;
		
		ExportFileName = GetFileFromServiceManagerStorage(ExportFileID);
			
		If ExportFileName = Undefined Then
			FatalErrorMessage = 
			NStr("ru = 'В менеджере сервиса больше нет требуемого файла начальных данных, вероятно он был заменен. Область не может быть подготовлена.'; en = 'Service manager no longer contains the required file with initial data, it might have been replaced. Area cannot be prepared.'; pl = 'Menedżer usług nie zawiera już wymaganego pliku z danymi początkowymi, mógł zostać zastąpiony. Obszar nie może być przygotowany.';es_ES = 'Gestor de servicio no contiene más el archivo requerido con los datos iniciales, puede ser que se haya reemplazado. Área no puede prepararse.';es_CO = 'Gestor de servicio no contiene más el archivo requerido con los datos iniciales, puede ser que se haya reemplazado. Área no puede prepararse.';tr = 'Hizmet yöneticisi artık başlangıç verileri içeren gereken dosyayı içermiyor, değiştirilmiş olabilir. Alan hazırlanamıyor.';it = 'Il gestore del servizio non ha più il file di dati iniziale richiesto, probabilmente è stato sostituito. L''area non può essere preparata.';de = 'Der Service Manager enthält nicht mehr die erforderliche Datei mit den Anfangsdaten, sondern wurde möglicherweise ersetzt. Bereich kann nicht vorbereitet werden.'");
			Return False;
		EndIf;
		
		SuppliedData.SaveSuppliedDataInCache(Descriptors.Descriptor[0], ExportFileName);
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not Common.SubsystemExists("CloudTechnology.SaaS.ExportImportDataAreas") Then
		
		RaiseNoCTLSubsystemException("CloudTechnology.SaaS.ExportImportDataAreas");
		
	EndIf;
	
	ModuleExportImportDataAreas = Common.CommonModule("ExportImportDataAreas");
	
	Try
		
		ImportIBUsers = False;
		CollapseUsers = (Not Constants.InfobaseUsageMode.Get() = Enums.InfobaseUsageModes.Demo);
		ModuleExportImportDataAreas.ImportCurrentDataAreaFromArchive(ExportFileName, ImportIBUsers, CollapseUsers);
		
	Except
		
		WriteLogEvent(EventLogEventDataAreaCopying(), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Try
			DeleteFiles(ExportFileName);
		Except
			WriteLogEvent(EventLogEventDataAreaCopying(), 
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		Raise;
	EndTry;
	
	Try
		DeleteFiles(ExportFileName);
	Except
		WriteLogEvent(EventLogEventDataAreaCopying(), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return "Success";

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Checking shared data.

// Checks whether it is possible to write separated data item. Raises exception if the data item cannot be written.
//
Procedure CheckSharedDataOnWrite(Val Source)
	
	If DataSeparationEnabled() AND SeparatedDataUsageAvailable() Then
		
		ExceptionPresentation = NStr("ru = 'Нарушение прав доступа.'; en = 'Access right violation.'; pl = 'Naruszenie praw dostępu.';es_ES = 'Violación del derecho de acceso.';es_CO = 'Violación del derecho de acceso.';tr = 'Erişim hakkı ihlali.';it = 'Violazione permessi di accesso.';de = 'Verletzung von Zugriffsrechten.'", CommonClientServer.DefaultLanguageCode());
		
		WriteLogEvent(
			ExceptionPresentation,
			EventLogLevel.Error,
			Source.Metadata());
		
		Raise ExceptionPresentation;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handling auxiliary area data.

// Handles the value of a reference type separated with the AuxiliaryDataSeparator separator 
// switching session separation while writes it.
//
// Parameters:
//  AuxiliaryDataObject - object of a reference type or ObjectDeletion,
//  Write - Boolean, flag that shows whether the value of a reference type must be written,
//  Delete - flag that shows whether the value of a reference type must be deleted.
//
Procedure HandleAuxiliaryData(AuxiliaryDataObject, Val Write, Val Delete)
	
	Try
		
		MustRestoreSessionSeparation = False;
		
		If TypeOf(AuxiliaryDataObject) = Type("ObjectDeletion") Then
			ValueToCheck = AuxiliaryDataObject.Ref;
			ReferenceBeingChecked = True;
		Else
			ValueToCheck = AuxiliaryDataObject;
			ReferenceBeingChecked = False;
		EndIf;
		
		If Not ExclusiveMode() AND IsSeparatedMetadataObject(ValueToCheck.Metadata(), AuxiliaryDataSeparator()) Then
			
			If SeparatedDataUsageAvailable() Then
				
				// In a separated session, just write the object.
				If Write Then
					AuxiliaryDataObject.Write();
				EndIf;
				If Delete Then
					AuxiliaryDataObject.Delete();
				EndIf;
				
			Else
				
				// In a shared session, switch session separation to avoid lock conflict of the sessions where 
				// another separator value is set.
				If ReferenceBeingChecked Then
					SeparatorValue = Common.ObjectAttributeValue(ValueToCheck, AuxiliaryDataSeparator());
				Else
					SeparatorValue = AuxiliaryDataObject[AuxiliaryDataSeparator()];
				EndIf;
				SetSessionSeparation(True, SeparatorValue);
				MustRestoreSessionSeparation = True;
				If Write Then
					AuxiliaryDataObject.Write();
				EndIf;
				If Delete Then
					AuxiliaryDataObject.Delete();
				EndIf;
				
			EndIf;
			
		Else
			
			If Write Then
				AuxiliaryDataObject.Write();
			EndIf;
			If Delete Then
				AuxiliaryDataObject.Delete();
			EndIf;
			
		EndIf;
		
		If MustRestoreSessionSeparation Then
			SetSessionSeparation(False);
		EndIf;
		
	Except
		
		If MustRestoreSessionSeparation Then
			SetSessionSeparation(False);
		EndIf;
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SUPPLIED DATA GETTING HANDLERS

Procedure HandleSuppliedAppliedSolutionPrototype(Val Descriptor, Val PathToFile)
	
	If ValueIsFilled(PathToFile) Then
		
		SuppliedData.SaveSuppliedDataInCache(Descriptor, PathToFile);
		
		DeleteObsoleteDataAreaPrototypes(Metadata.Version);
		
	Else
		
		Filter = New Array;
		For each Characteristic In Descriptor.Properties.Property Do
			If Characteristic.IsKey Then
				Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
			EndIf;
		EndDo;

		For each Ref In SuppliedData.SuppliedDataReferencesFromCache(Descriptor.DataType, Filter) Do
		
			SuppliedData.DeleteSuppliedDataFromCache(Ref);
		
		EndDo;
	EndIf;
	
EndProcedure

// Removes obsolete data area prototypes whose version is earlier than the specified (latest).
//
// Parameters:
//  LatestConfigurationVersion - String - the latest configuration version.
//
Procedure DeleteObsoleteDataAreaPrototypes(LatestConfigurationVersion)
	
	Query = New Query(
		"SELECT DISTINCT
		|	DataCharacteristicsSuppliedData.Ref.Ref AS SuppliedData,
		|	CAST(DataCharacteristicsSuppliedData.Value AS STRING(150)) AS ConfigurationVersion
		|FROM
		|	Catalog.SuppliedData.DataCharacteristics AS DataCharacteristicsSuppliedData
		|WHERE
		|	DataCharacteristicsSuppliedData.Characteristic = ""ConfigurationVersion""
		|	AND DataCharacteristicsSuppliedData.Ref.DataKind = ""DataAreaPrototype""");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If CommonClientServer.CompareVersions(LatestConfigurationVersion, Selection.ConfigurationVersion) > 0 Then
			SuppliedData.DeleteSuppliedDataFromCache(Selection.SuppliedData);
		EndIf;
	EndDo;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE HANDLERS

// Transfers data from the DeleteDataAreas information register to the DataAreas information register.
//
Procedure MoveDataAreas() Export
	
	BeginTransaction();
	
	Try
		
		QueryText =
		"SELECT
		|	ISNULL(DataAreas.DataAreaAuxiliaryData, DeleteDataAreas.DataArea) AS DataAreaAuxiliaryData,
		|	DeleteDataAreas.Presentation,
		|	ISNULL(DataAreas.Status, DeleteDataAreas.Status) AS Status,
		|	DeleteDataAreas.Prefix,
		|	ISNULL(DataAreas.Repeat, DeleteDataAreas.Repeat) AS Repeat,
		|	DeleteDataAreas.TimeZone,
		|	ISNULL(DataAreas.ExportID, DeleteDataAreas.ExportID) AS ExportID,
		|	ISNULL(DataAreas.ProcessingError, DeleteDataAreas.ProcessingError) AS ProcessingError,
		|	ISNULL(DataAreas.Variant, DeleteDataAreas.Variant) AS Variant
		|FROM
		|	InformationRegister.DeleteDataAreas AS DeleteDataAreas
		|		FULL JOIN InformationRegister.DataAreas AS DataAreas
		|		ON DeleteDataAreas.DataArea = DataAreas.DataAreaAuxiliaryData";		Query = New Query(QueryText);
		TransferTable = Query.Execute().Unload();
		
		For Each Transfer In TransferTable Do
			
			Manager = InformationRegisters.DataAreas.CreateRecordManager();
			Manager.DataAreaAuxiliaryData = Transfer.DataAreaAuxiliaryData;
			Manager.Read();
			If Not Manager.Selected() Then
				FillPropertyValues(Manager, Transfer);
				Manager.Write();
			EndIf;
			
			If ValueIsFilled(Transfer.Presentation) Then
				
				Manager = Constants.DataAreaPresentation.CreateValueManager();
				Manager.DataAreaAuxiliaryData = Transfer.DataAreaAuxiliaryData;
				Manager.Read();
				If Not ValueIsFilled(Manager.Value) Then
					Manager.Value = Transfer.Presentation;
					Manager.Write();
				EndIf;
				
			EndIf;
			
			If ValueIsFilled(Transfer.Prefix) Then
				
				Manager = Constants.DataAreaPrefix.CreateValueManager();
				Manager.DataAreaAuxiliaryData = Transfer.DataAreaAuxiliaryData;
				Manager.Read();
				If Not ValueIsFilled(Manager.Value) Then
					Manager.Value = Transfer.Prefix;
					Manager.Write();
				EndIf;
				
			EndIf;
			
			If ValueIsFilled(Transfer.TimeZone) Then
				
				Manager = Constants.DataAreaTimeZone.CreateValueManager();
				Manager.DataAreaAuxiliaryData = Transfer.DataAreaAuxiliaryData;
				Manager.Read();
				If Not ValueIsFilled(Manager.Value) Then
					Manager.Value = Transfer.TimeZone;
					Manager.Write();
				EndIf;
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Disables the use of a separator for infobase users.
// DataAreaAuxiliaryData.
//
Procedure DisableUserSeparationByInternalDataSeparator() Export
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each InfobaseUser In IBUsers Do
		
		If InfobaseUser.DataSeparation.Property(AuxiliaryDataSeparator()) Then
			InfobaseUser.DataSeparation.Delete(AuxiliaryDataSeparator());
			InfobaseUser.Write();
		EndIf;
		
	EndDo;
	
EndProcedure

// Verifies the metadata structure. Shared data must be protected from writing from sessions with 
// separators disabled.
//
Function CheckSharedDataOnUpdate(RaiseException = True) Export
	
	MetadataVerificationRules = New Map;
	
	MetadataVerificationRules.Insert(Metadata.Constants, "ConstantValueManager.%1");
	MetadataVerificationRules.Insert(Metadata.Catalogs, "CatalogObject.%1");
	MetadataVerificationRules.Insert(Metadata.Documents, "DocumentObject.%1");
	MetadataVerificationRules.Insert(Metadata.BusinessProcesses, "BusinessProcessObject.%1");
	MetadataVerificationRules.Insert(Metadata.Tasks, "TaskObject.%1");
	MetadataVerificationRules.Insert(Metadata.ChartsOfCalculationTypes, "ChartOfCalculationTypesObject.%1");
	MetadataVerificationRules.Insert(Metadata.ChartsOfCharacteristicTypes, "ChartOfCharacteristicTypesObject.%1");
	MetadataVerificationRules.Insert(Metadata.ExchangePlans, "ExchangePlanObject.%1");
	MetadataVerificationRules.Insert(Metadata.ChartsOfAccounts, "ChartOfAccountsObject.%1");
	MetadataVerificationRules.Insert(Metadata.AccountingRegisters, "AccountingRegisterRecordSet.%1");
	MetadataVerificationRules.Insert(Metadata.AccumulationRegisters, "AccumulationRegisterRecordSet.%1");
	MetadataVerificationRules.Insert(Metadata.CalculationRegisters, "CalculationRegisterRecordSet.%1");
	MetadataVerificationRules.Insert(Metadata.InformationRegisters, "InformationRegisterRecordSet.%1");
	
	Exceptions = New Array();
	
	Exceptions.Add(Metadata.InformationRegisters.ProgramInterfaceCache);
	Exceptions.Add(Metadata.Constants.InstantMessageSendingLocked);
	
	// StandardSubsystems.DataExchange
	Exceptions.Add(Metadata.InformationRegisters.SafeDataStorage);
	Exceptions.Add(Metadata.InformationRegisters.DeleteExchangeTransportSettings);
	Exceptions.Add(Metadata.InformationRegisters.DataExchangesStates);
	Exceptions.Add(Metadata.InformationRegisters.SuccessfulDataExchangesStates);
	// End StandardSubsystems.DataExchange
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		Exceptions.Add(Metadata.Catalogs.Find("KeyOperations"));
		Exceptions.Add(Metadata.Catalogs.Find("KeyOperationProfiles"));
		Exceptions.Add(Metadata.InformationRegisters.Find("TimeMeasurements"));
		Exceptions.Add(Metadata.InformationRegisters.Find("TimeMeasurementsTechnological"));
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Exceptions.Add(Metadata.InformationRegisters.Find("PlatformDumps"));
		Exceptions.Add(Metadata.InformationRegisters.Find("StatisticsOperations"));
		Exceptions.Add(Metadata.InformationRegisters.Find("StatisticsComments"));
		Exceptions.Add(Metadata.InformationRegisters.Find("StatisticsAreas"));
		Exceptions.Add(Metadata.InformationRegisters.Find("StatisticsOperationComments"));
		Exceptions.Add(Metadata.InformationRegisters.Find("StatisticsOperationsClipboard"));
		Exceptions.Add(Metadata.InformationRegisters.Find("MeasurementsStatisticsOperations"));
		Exceptions.Add(Metadata.InformationRegisters.Find("MeasurementsStatisticsComments"));
		Exceptions.Add(Metadata.InformationRegisters.Find("MeasurementsStatisticsAreas"));
		Exceptions.Add(Metadata.InformationRegisters.Find("ConfigurationStatistics"));
		Exceptions.Add(Metadata.InformationRegisters.Find("PackagesToSend"));
        Exceptions.Add(Metadata.InformationRegisters.Find("StatisticsMeasurements"));
	EndIf;
	
	SaaSIntegration.OnDefineSharedDataExceptions(Exceptions);
	
	StandardSeparators = New Array;
	StandardSeparators.Add(Metadata.CommonAttributes.DataAreaMainData);
	StandardSeparators.Add(Metadata.CommonAttributes.DataAreaAuxiliaryData);
	
	VerificationProcedures = New Array;
	VerificationProcedures.Add(Metadata.EventSubscriptions.CheckSharedRecordsSetsOnWrite.Handler);
	VerificationProcedures.Add(Metadata.EventSubscriptions.CheckSharedObjectsOnWrite.Handler);
	
	VerificationSubscriptions = New Array;
	For Each EventSubscription In Metadata.EventSubscriptions Do
		If VerificationProcedures.Find(EventSubscription.Handler) <> Undefined Then
			VerificationSubscriptions.Add(EventSubscription);
		EndIf;
	EndDo;
	
	SharedDataIncludingInVerificationSubscriptionsVerificationViolations = New Array();
	MultipleSeparatorObjectSeparationVerificationViolations = New Array();
	MetadataObjectsWithViolations = New Array;
	
	For Each MetadataVerificationRule In MetadataVerificationRules Do
		
		MetadataObjectsToVerify = MetadataVerificationRule.Key;
		MetadataObjectsTypeConstructor = MetadataVerificationRule.Value;
		
		For Each MetadataObjectToVerify In MetadataObjectsToVerify Do
			
			// 1. Metadata object several separator verification.
			
			SeparatorCount = 0;
			For Each StandardSeparator In StandardSeparators Do
				If IsSeparatedMetadataObject(MetadataObjectToVerify, StandardSeparator.Name) Then
					SeparatorCount = SeparatorCount + 1;
				EndIf;
			EndDo;
			
			If SeparatorCount > 1 Then
				MultipleSeparatorObjectSeparationVerificationViolations.Add(MetadataObjectToVerify);
				MetadataObjectsWithViolations.Add(MetadataObjectToVerify);
			EndIf;
			
			// 2. Checking whether shared metadata objects are included in the verification event subscription 
			// content.
			
			If ValueIsFilled(MetadataObjectsTypeConstructor) Then
				
				If Exceptions.Find(MetadataObjectToVerify) <> Undefined Then
					Continue;
				EndIf;
				
				MetadataObjectType = Type(StringFunctionsClientServer.SubstituteParametersToString(MetadataObjectsTypeConstructor, MetadataObjectToVerify.Name));
				
				VerificationRequired = True;
				For Each StandardSeparator In StandardSeparators Do
					
					If IsSeparatedMetadataObject(MetadataObjectToVerify, StandardSeparator.Name) Then
						
						VerificationRequired = False;
						
					EndIf;
					
				EndDo;
				
				VerificationProvided = False;
				If VerificationRequired Then
					
					For Each VerificationSubscription In VerificationSubscriptions Do
						
						If VerificationSubscription.Source.ContainsType(MetadataObjectType) Then
							VerificationProvided = True;
						EndIf;
						
					EndDo;
					
				EndIf;
				
				If VerificationRequired AND Not VerificationProvided Then
					SharedDataIncludingInVerificationSubscriptionsVerificationViolations.Add(MetadataObjectToVerify);
					MetadataObjectsWithViolations.Add(MetadataObjectToVerify);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	ExceptionsToRaise = New Array();
	
	SeparatorText = "";
	For Each StandardSeparator In StandardSeparators Do
		
		If Not IsBlankString(SeparatorText) Then
			SeparatorText = SeparatorText + ", ";
		EndIf;
		
		SeparatorText = SeparatorText + StandardSeparator.Name;
		
	EndDo;
	
	If SharedDataIncludingInVerificationSubscriptionsVerificationViolations.Count() > 0 Then
		
		ExceptionText = "";
		For Each UncontrolledMetadataObject In SharedDataIncludingInVerificationSubscriptionsVerificationViolations Do
			
			If Not IsBlankString(ExceptionText) Then
				ExceptionText = ExceptionText + ", ";
			EndIf;
			
			ExceptionText = ExceptionText + UncontrolledMetadataObject.FullName();
			
		EndDo;
		
		SubscriptionText = "";
		For Each VerificationSubscription In VerificationSubscriptions Do
			
			If Not IsBlankString(SubscriptionText) Then
				SubscriptionText = SubscriptionText + ", ";
			EndIf;
			
			SubscriptionText = SubscriptionText + VerificationSubscription.Name;
			
		EndDo;
		
		ExceptionsToRaise.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Все объекты метаданных, не входящие в состав разделителей БСП (%1),
                  |должны быть включены в состав подписок на события (%2), контролирующих
                  |невозможность записи неразделенных данных в разделенных сеансах.
                  |Следующие объекты метаданных не удовлетворяют этому критерию: %3.'; 
                  |en = 'All configuration metadata objects not belonging to SL separators (%1)
                  |should be included in event subscriptions (%2) which 
                  |prevent shared data from writing in the split mode. 
                  |The following metadata objects do not meet this criterion: %3.'; 
                  |pl = 'Wszystkie elementy metadanych, nie wchodzące w skład separatorów BSP (%1),
                  |muszą być włączone w skład subskrypcji na wydarzenia (%2), kontrolujących
                  |brak możliwości zapisywania niepodzielonych danych w podzielonych sesjach.
                  |Następujące elementy metadanych nie spełniają tego kryterium: %3.';
                  |es_ES = 'Todos los objetos de metadatos que no están incluidos en el contenido de los separadores de SSL (%1),
                  |deben estar incluidos en el contenido de las suscripciones a los eventos (%2) que controlan
                  |la imposibilidad de guardar los datos no distribuidos en las sesiones distribuidas.
                  |Los siguientes objetos de metadatos no satisfacen a este criterio: %3.';
                  |es_CO = 'Todos los objetos de metadatos que no están incluidos en el contenido de los separadores de SSL (%1),
                  |deben estar incluidos en el contenido de las suscripciones a los eventos (%2) que controlan
                  |la imposibilidad de guardar los datos no distribuidos en las sesiones distribuidas.
                  |Los siguientes objetos de metadatos no satisfacen a este criterio: %3.';
                  |tr = 'BSP (%1) 
                  |ayırıcılarının bir parçası olmayan tüm meta veri nesneleri, bölünmüş oturumlarda bölünmemiş verileri %3kaydedilemeyen olayları (%2) izleyen aboneliklere dahil edilmelidir. 
                  |Aşağıdaki meta veri nesneleri bu kriteri karşılamıyor: 
                  |.';
                  |it = 'Tutti gli oggetti dei metadati non rientranti a far parte dei separatori della Libreria dei Sottosistemi Standard (%1), 
                  | devono essere inclusi nelle sottoscrizioni agli eventi (%2), controllanti 
                  | l''impossibilità della registrazione di dati non condivisi all''interno di sessioni separate. 
                  | I seguenti oggetti di metadati non soddisfano questo criterio: %3.';
                  |de = 'Alle Metadatenobjekte, die nicht Teil der Trennzeichen der BSP (%1) sind,
                  |sollten in Ereignis-Abonnements (%2) aufgenommen werden, die die Unmöglichkeit des Schreibens ungeteilter Daten in Split-Sitzungen steuern
                  |.
                  |Die folgenden Metadatenobjekte erfüllen dieses Kriterium nicht: %3.'"),
			SeparatorText, SubscriptionText, ExceptionText));
		
	EndIf;
	
	If MultipleSeparatorObjectSeparationVerificationViolations.Count() > 0 Then
		
		ExceptionText = "";
		
		For Each BreakingMetadataObject In MultipleSeparatorObjectSeparationVerificationViolations Do
			
			If Not IsBlankString(ExceptionText) Then
				ExceptionText = ExceptionText + ", ";
			EndIf;
			
			ExceptionText = ExceptionText + BreakingMetadataObject.FullName();
			
		EndDo;
		
		ExceptionsToRaise.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Все объекты метаданных конфигурации должны быть разделены не более чем одним разделителем БСП (%1).
                  |Следующие объекты не удовлетворяют этому критерию: %2'; 
                  |en = 'All configuration metadata objects should be divided by at most one SL separator (%1).
                  |The following objects do not meet this criterion: %2'; 
                  |pl = 'Wszystkie elementy metadanych konfiguracji powinny być podzielone nie więcej niż jednym separatorem BSP (%1).
                  | Następujące elementy nie spełniają tego kryterium: %2';
                  |es_ES = 'Todos los objetos de metadatos de la configuración deben estar divididos con no más de un separador de SSL (%1).
                  |Los siguientes objetos no satisfacen al criterio: %2';
                  |es_CO = 'Todos los objetos de metadatos de la configuración deben estar divididos con no más de un separador de SSL (%1).
                  |Los siguientes objetos no satisfacen al criterio: %2';
                  |tr = 'Tüm yapılandırma meta veri nesneleri birden fazla BSP (%1) ayırıcı tarafından bölünmelidir. 
                  |Aşağıdaki nesneler bu kriteri karşılamıyor:%2';
                  |it = 'Tutti gli oggetti della configurazione dei metadati devono essere separati da non più di un separatore dell Libreria dei Sottosistemi Standard (%1). 
                  | I seguenti oggetti non soddisfano questo criterio: %2';
                  |de = 'Alle Metadatenobjekte in der Konfiguration dürfen durch nicht mehr als einen BSP-Trennzeichen (%1) getrennt sein.
                  |Die folgenden Objekte erfüllen dieses Kriterium nicht: %2'"),
			SeparatorText, ExceptionText));
		
	EndIf;
	
	ResultException = "";
	Iterator = 1;
	
	For Each ExceptionToRaise In ExceptionsToRaise Do
		
		If Not IsBlankString(ResultException) Then
			ResultException = ResultException + Chars.LF + Chars.CR;
		EndIf;
		
		ResultException = ResultException + Format(Iterator, "NFD=0; NG=0") + ". " + ExceptionToRaise;
		Iterator = Iterator + 1;
		
	EndDo;
	
	If Not IsBlankString(ResultException) Then
		
		ResultException = NStr("ru = 'Обнаружены ошибки в структуре метаданных конфигурации:'; en = 'The following errors are found in the applied solution metadata structure:'; pl = 'Wykryto błędy w strukturze metadanych konfiguracji:';es_ES = 'Errores encontrados en la estructura de la configuración de metadatos:';es_CO = 'Errores encontrados en la estructura de la configuración de metadatos:';tr = 'Meta veri yapılandırmasının yapısında bulunan hatalar:';it = 'Sono stati rilevati degli errori nella struttura della configurazione dei metadati:';de = 'Es wurden Fehler in der Struktur der Konfigurationsmetadaten festgestellt:'") + Chars.LF + Chars.CR + ResultException;
		
		If RaiseException Then
			
			Raise ResultException;
			
		Else
			
			Return New Structure("MetadataObjects, ExceptionText", MetadataObjectsWithViolations, ResultException);
			
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Verifies the metadata structure. Common data must be ordered in the configuration metadata tree.
// 
//
Procedure CheckSeparatorsOnUpdate() Export
	
	AppliedDataOrder = 99;
	InternalDataOrder = 99;
	
	AppliedSeparator = Metadata.CommonAttributes.DataAreaMainData;
	InternalSeparator = Metadata.CommonAttributes.DataAreaAuxiliaryData;
	
	Iterator = 0;
	For Each CommonConfigurationAttribute In Metadata.CommonAttributes Do
		
		If CommonConfigurationAttribute = AppliedSeparator Then
			AppliedDataOrder = Iterator;
		ElsIf CommonConfigurationAttribute = InternalSeparator Then
			InternalDataOrder = Iterator;
		EndIf;
		
		Iterator = Iterator + 1;
		
	EndDo;
	
	If AppliedDataOrder <= InternalDataOrder Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Обнаружено нарушение структуры метаданных конфигурации: общий реквизит %1 должен
                  |быть расположен в дереве метаданных конфигурации до общего реквизита
                  |%2 по порядку.'; 
                  |en = 'Configuration metadata structure violation detected: common attribute %1
                  |must be placed before common attribute
                  |%2 in the configuration metadata tree.'; 
                  |pl = 'Wykryto naruszenie struktury metadanych konfiguracji: ogólny rekwizyt %1 powinien
                  |być położony w drzewie metadanych konfiguracji do wspólnego rekwizytu
                  |%2 po kolei.';
                  |es_ES = 'Ruptura de la estructura de los metadatos de la configuración se ha encontrado: atributo común %1 tiene que
                  |ubicarse en el árbol de los metadatos de la configuración hasta el atributo común
                  |%2 en orden.';
                  |es_CO = 'Ruptura de la estructura de los metadatos de la configuración se ha encontrado: atributo común %1 tiene que
                  |ubicarse en el árbol de los metadatos de la configuración hasta el atributo común
                  |%2 en orden.';
                  |tr = 'Yapılandırma meta veri yapısında kırılma tespit edildi: ortak özellik
                  |, sırayla sıraya göre yapılandırma %1 metaveri 
                  |ağacında %2 yer almalıdır.';
                  |it = 'È stata individuata una violazione della struttura della configurazione dei metadati: il requisito generale %1 deve 
                  | essere disposto sull''albero della configurazione dei metadati fino al requisito generale 
                  |%2 relativo all''ordine.';
                  |de = 'Es wurde eine Verletzung der Struktur der Konfigurationsmetadaten festgestellt: Die gemeinsamen Requisiten %1 sollten
                  |sich im Konfigurationsmetadatenbaum bis zum gemeinsamen Requisit
                  |%2 befinden.'"),
			InternalSeparator.Name,
			AppliedSeparator.Name);
		
	EndIf;
	
EndProcedure

// Transfers records from the DeleteDataAreaActivityRating information register to the DataAreaActivityRating information register.
//
Procedure MoveDataAreaActivityRating() Export
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock();
		Lock.Add("InformationRegister.DataAreaActivityRating");
		Lock.Add("InformationRegister.DeleteDataAreaActivityRating");
		Lock.Lock();
		
		InformationRegisters.DataAreaActivityRating.CreateRecordSet().Write();
		
		Set = Undefined;
		
		Selection = InformationRegisters.DeleteDataAreaActivityRating.Select();
		While Selection.Next() Do
			
			If Set = Undefined Then
				Set = InformationRegisters.DataAreaActivityRating.CreateRecordSet();
			EndIf;
			
			Record = Set.Add();
			Record.DataAreaAuxiliaryData = Selection.DataArea;
			Record.Rating = Selection.Rating;
			
			If Set.Count() >= 10000 Then
				Set.Write(False);
				Set = Undefined;
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Returns the earliest 1C:Cloud technology library version supported by the current SL version.
// 
//
// Returns: String, earliest supported CTL version in the RR.{S|SS}.ZZ.CC format.
//
Function RequiredSTLVersion()
	
	Return "1.0.2.1";
	
EndFunction

#EndRegion
