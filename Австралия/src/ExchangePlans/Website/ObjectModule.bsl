
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure EnableDisableScheduledJob(JobSchedule) Export
	
	
	Job = CurrentJob();
	If UseAutomaticExchange Then
		
		JobParameters = JobProperties(JobSchedule);
		
		If Job = Undefined Then
			
			JobParameters.Insert("Metadata", Metadata.ScheduledJobs.ExchangeWithWebsite);
			JobParameters.Insert("Key", String(New UUID));
			JobParameters.Insert("Use", True);
			
			JobID = NewJob(JobParameters);
			ScheduledJobID = JobID;
		Else
			SetJobParameters(Job, JobParameters);
		EndIf;
		
	Else
		
		If Job <> Undefined Then
			DeleteJob(Job);
		EndIf;
		ScheduledJobID = Undefined;
		
	EndIf;

EndProcedure

Function CurrentJob() Export
	
	Filter = New Structure;
	
	If Common.DataSeparationEnabled() Then
		Filter.Insert("Key", ScheduledJobID);
	Иначе
		If ValueIsFilled(ScheduledJobID) Then
			Filter.Insert("ID", New UUID(ScheduledJobID));
		EndIf;
		Filter.Insert("Description", ScheduledJobDescription());
		
	EndIf;

	Filter.Insert("Metadata", Metadata.ScheduledJobs.ExchangeWithWebsite);
	
	Found = ScheduledJobsServer.FindJobs(Filter);
	Job = ?(Found.Count() = 0, Undefined, Found[0]);
	
	Return Job;
	
EndFunction

Function JobProperties(JobSchedule = Undefined) Export
	
	Parameters = New Array;
	Parameters.Add(Code);
	
	JobParameters = New Structure;
	If Not JobSchedule = Undefined Then
		JobParameters.Insert("Schedule", JobSchedule);
	EndIf;
	JobParameters.Insert("Parameters", Parameters);
	JobParameters.Insert("MethodName", Metadata.ScheduledJobs.ExchangeWithWebsite.MethodName);
	JobParameters.Insert("Description", ScheduledJobDescription());

	Return JobParameters;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure BeforeDelete(Cancel)
	
	// There is no DataExchange.Import property value verification as the code below implements the 
	// logic, which must be executed, including when this property is set to True (on the side of the 
	// code that attempts to record to this exchange plan).
	
	// The exchange plan uses a safe storage, that is why the correspondent record must be deleted from 
	// the storage when deleting an exchange node (according to basic functionality subsystem 
	// documentation).
	
	SetPrivilegedMode(True);
	Common.DeleteDataFromSecureStorage(Ref);
	SetPrivilegedMode(False);
	
EndProcedure

Procedure BeforeWrite(Cancel)
		
	If IsBlankString(Code) Then
		SetNewCode();
	EndIf;
	
	PriceTypes.GroupBy("PriceType");
	Warehouses.GroupBy("Warehouse");
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If ImportOrders Then
		
		Item = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FindByDescription(NStr("en = 'ID on website'; ru = 'Идентификатор на сайте';pl = 'Identyfikator na stronie internetowej';es_ES = 'ID en el sitio web';es_CO = 'ID en el sitio web';tr = 'Web sitesindeki kimlik numarası';it = 'ID su sito web';de = 'ID auf Webseite'"));
		If Not ValueIsFilled(Item) Then
			
			SalesOrders = NStr("en = 'Sales orders'; ru = 'Заказы покупателей';pl = 'Zamówienia sprzedaży';es_ES = 'Órdenes de ventas';es_CO = 'Órdenes de ventas';tr = 'Satış siparişleri';it = 'Ordini Cliente';de = 'Kundenaufträge'");
			PropertySet = Catalogs.AdditionalAttributesAndInfoSets.FindByDescription(SalesOrders);
			
			Property = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.CreateItem();
			Property.Title			= NStr("en = 'ID on website'; ru = 'Идентификатор на сайте';pl = 'Identyfikator na stronie internetowej';es_ES = 'ID en el sitio web';es_CO = 'ID en el sitio web';tr = 'Web sitesindeki kimlik numarası';it = 'ID su sito web';de = 'ID auf Webseite'");
			Property.Description	= StringFunctionsClientServer.SubstituteParametersToString(Property.Title + " (%1)",
				SalesOrders);
			Property.Visible		= True;
			Property.Available		= True;
			Property.ValueType		= New TypeDescription("Number");
			Property.PropertySet	= PropertySet;
			
			Name = StringFunctionsClientServer.ReplaceCharsWithOther("-  ", Title(Property.Title) + "_" + New UUID, "");
			Property.Name			= Name;
			Property.Write();
			
			PropertySetObject = PropertySet.GetObject();
			
			NewRow = PropertySetObject.AdditionalAttributes.Add();
			NewRow.Property = Property.Ref;
			PropertySetObject.AttributesNumber = PropertySetObject.AttributesNumber + 1;
			PropertySetObject.Write();
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ThisNode Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IntegrationComponent");
	EndIf;
	
	If Not ImportOrders
		Or ImportCustomers Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "DefaultCustomer");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function ScheduledJobDescription()
	
	Name = NStr("en = 'Data exchange with website: %1.'; ru = 'Обмен данными с веб-сайтом: %1.';pl = 'Wymiana danych ze stroną internetową: %1.';es_ES = 'Intercambio de datos con el sitio web: %1.';es_CO = 'Intercambio de datos con el sitio web: %1.';tr = 'Web sitesi ile veri değişimi: %1.';it = 'Scambio dati con il sito web: %1.';de = 'Datenaustausch mit Webseite: %1.'");
	JobName = StringFunctionsClientServer.SubstituteParametersToString(Name, Code);
	
	Return JobName;
	
EndFunction

Procedure DeleteJob(Job)
	
	ScheduledJobsServer.DeleteJob(Job);
	
EndProcedure

Function NewJob(JobParameters)
	
	ScheduledJob = ScheduledJobsServer.AddJob(JobParameters);
	
	If TypeOf(ScheduledJob) = Type("ValueTableRow") Then
		ID = ScheduledJob.Key;
	Else
		ID = String(ScheduledJob.UUID);
	EndIf;
	
	Return ID;
	
EndFunction

Procedure SetJobParameters(Job, JobProperties)
	
	If Job = Undefined Then
		Return;
	EndIf;
	
	ScheduledJobsServer.ChangeJob(Job, JobProperties);
	SetPrivilegedMode(True);
	
EndProcedure

#EndRegion

#EndIf