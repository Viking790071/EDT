#Region Private

// Returns mapping between methods and method aliases (uppercase) that can be called from the job 
// queue.
//
// Returns:
//  FixedMap
//   Key - method alias
//   Value - method name used for calling.
//
Function MapBetweenMethodNamesAndAliases() Export
	
	Result = New Map;
	
	ApplicationMethods = New Map;
	
	SSLSubsystemsIntegration.OnDefineHandlerAliases(ApplicationMethods);
	
	// Determining internal procedure methods used for job error handling.
	ApplicationMethods.Insert("JobQueueInternal.HandleError");
	ApplicationMethods.Insert("JobQueueInternal.CancelErrorHandlerJobs");
	
	JobsQueueOverridable.OnDefineHandlerAliases(ApplicationMethods);
	
	For each KeyAndValue In ApplicationMethods Do
		Result.Insert(Upper(KeyAndValue.Key),
			?(IsBlankString(KeyAndValue.Value), KeyAndValue.Key, KeyAndValue.Value));
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns mapping between error handlers and aliases of methods called for these error handlers 
// (uppercase.
//
// Returns:
//  FixedMap
//   Key - method alias
//   Value - full name of handler method.
//
Function MapBetweenErrorHandlersAndAliases() Export
	
	ErrorHandlers = New Map;
	
	// Filling the embedded error handlers.
	ErrorHandlers.Insert("JobQueueInternal.HandleError","JobQueueInternal.CancelErrorHandlerJobs");
	ErrorHandlers.Insert("JobQueueInternal.CancelErrorHandlerJobs","JobQueueInternal.CancelErrorHandlerJobs");
	
	SSLSubsystemsIntegration.OnDefineErrorHandlers(ErrorHandlers);
	JobsQueueOverridable.OnDefineErrorHandlers(ErrorHandlers);
	
	Result = New Map;
	For each KeyAndValue In ErrorHandlers Do
		Result.Insert(Upper(KeyAndValue.Key), KeyAndValue.Value);
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns description of queue job parameters.
//
// Returns:
//  ValueTable - parameter details, columns.
//   Name - String - a parameter name.
//   NameUpper - String - parameter name in uppercase.
//   Field - String - field used to store the parameter in queue table.
//   Type - TypesDetails - allowed parameter value types.
//   Filter - Boolean - this parameter can be used as filter.
//   Adding - Boolean - this parameter can be used when adding a job to queue.
//    
//   Changing - Boolean - this parameter can be edited.
//   Template - Boolean - this parameter can be edited for jobs created by template.
//    
//   DataSeparation - Boolean - this parameter is only used for separated job management.
//    
//   ValueForUnseparatedJobs - String - this value must be returned from API for separated 
//     parameters of unseparated jobs (as a string that can be substituted into queries).
//     
//
Function QueueJobParameters() Export
	
	Result = New ValueTable;
	Result.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("UpperCaseName", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Field", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	Result.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Result.Columns.Add("Filter", New TypeDescription("Boolean"));
	Result.Columns.Add("Insert", New TypeDescription("Boolean"));
	Result.Columns.Add("Update", New TypeDescription("Boolean"));
	Result.Columns.Add("Template", New TypeDescription("Boolean"));
	Result.Columns.Add("DataSeparation", New TypeDescription("Boolean"));
	Result.Columns.Add("ValueForUnseparatedJobs", New TypeDescription("String"));
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "DataArea";
	ParameterDetails.Field = "DataAreaAuxiliaryData";
	ParameterDetails.Type = New TypeDescription("Number");
	ParameterDetails.Filter = True;
	ParameterDetails.Insert = True;
	ParameterDetails.DataSeparation = True;
	ParameterDetails.ValueForUnseparatedJobs = "-1";
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "ID";
	ParameterDetails.Field = "Ref";
	TypesArray = New Array();
	JobCatalogs = JobsQueueInternalCached.GetJobCatalogs();
	For Each CatalogJob In JobCatalogs Do
		TypesArray.Add(TypeOf(CatalogJob.EmptyRef()));
	EndDo;
	ParameterDetails.Type = New TypeDescription(TypesArray);
	ParameterDetails.Filter = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "Use";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("Boolean");
	ParameterDetails.Filter = True;
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	ParameterDetails.Template = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "ScheduledStartTime";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("Date");
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	ParameterDetails.Template = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "JobState";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("EnumRef.JobsStates");
	ParameterDetails.Filter = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "ExclusiveExecution";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("Boolean");
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	ParameterDetails.Template = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "Template";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("CatalogRef.QueueJobTemplates");
	ParameterDetails.Filter = True;
	ParameterDetails.DataSeparation = True;
	ParameterDetails.ValueForUnseparatedJobs = "UNDEFINED";
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "MethodName";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("String");
	ParameterDetails.Filter = True;
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "Parameters";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("Array");
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "Key";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("String");
	ParameterDetails.Filter = True;
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "RestartIntervalOnFailure";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("Number");
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	ParameterDetails.Template = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "Schedule";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("JobSchedule, Undefined");
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	ParameterDetails.Template = True;
	
	ParameterDetails = Result.Add();
	ParameterDetails.Name = "RestartCountOnFailure";
	ParameterDetails.Field = ParameterDetails.Name;
	ParameterDetails.Type = New TypeDescription("Number");
	ParameterDetails.Insert = True;
	ParameterDetails.Update = True;
	ParameterDetails.Template = True;
	
	For each ParameterDetails In Result Do
		ParameterDetails.UpperCaseName = Upper(ParameterDetails.Name);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns allowed comparison types for queue job filters.
Function JobFilterComparisonTypes() Export
	
	Result = New Map;
	Result.Insert(ComparisonType.Equal, "=");
	Result.Insert(ComparisonType.NotEqual, "<>");
	Result.Insert(ComparisonType.InList, "IN");
	Result.Insert(ComparisonType.NotInList, "NOT IN");
	
	Return New FixedMap(Result);
	
EndFunction

// Returns partial text of job retrieval query to be returned via application interface.
// 
//
// Parameters:
//  CatalogJob - CatalogManager, manager of the catalog used to retrieve the queue jobs.
//   Used to filter selection fields only applicable to some of the job catalogs.
//  
//
Function JobQueueSelectionFields(Val CatalogJob = Undefined) Export
	
	SelectionFields = "";
	For each ParameterDetails In JobsQueueInternalCached.QueueJobParameters() Do
		
		If NOT IsBlankString(SelectionFields) Then
			SelectionFields = SelectionFields + "," + Chars.LF;
		EndIf;
		
		SelectionFieldDescription = "PositionInQueue." + ParameterDetails.Field + " AS " + ParameterDetails.Name;
		
		If CatalogJob <> Undefined Then
			
			If ParameterDetails.DataSeparation Then
				
				If Not SaaSCached.IsSeparatedConfiguration() OR Not SaaS.IsSeparatedMetadataObject(CatalogJob, SaaS.AuxiliaryDataSeparator()) Then
					
					SelectionFieldDescription = ParameterDetails.ValueForUnseparatedJobs + " AS " + ParameterDetails.Name;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		SelectionFields = SelectionFields + Chars.Tab + SelectionFieldDescription;
		
	EndDo;
	
	Return SelectionFields;
	
EndFunction

// Returns an array of catalog managers that can be used to store queue jobs.
// 
//
Function GetJobCatalogs() Export
	
	CatalogArray = New Array();
	CatalogArray.Add(Catalogs.JobQueue);
	
	If SaaSCached.IsSeparatedConfiguration() Then
		ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
		ModuleJobQueueInternalDataSeparation.OnFillJobCatalog(CatalogArray);
	EndIf;
	
	Return New FixedArray(CatalogArray);
	
EndFunction

#EndRegion
