#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Moves all users from the Data Administrators access group into the Administrators access group.
// 
//  Deletes the Data administrator profile and the Data administrators access group.
// 
Procedure UpdateAdministratorAccessGroupsSaaS() Export
	
	SetPrivilegedMode(True);
	
	DataAdministratorProfileRef = Catalogs.AccessGroupProfiles.GetRef(
		New UUID("f0254dd0-3558-4430-84c7-154c558ae1c9"));
		
	AccessGroupDataAdministratorsRef = Catalogs.AccessGroups.GetRef(
		New UUID("c7684994-34c9-4ddc-b31c-05b2d833e249"));
	
	Query = New Query;
	Query.SetParameter("DataAdministratorProfileRef",        DataAdministratorProfileRef);
	Query.SetParameter("AccessGroupDataAdministratorsRef", AccessGroupDataAdministratorsRef);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Ref = &AccessGroupDataAdministratorsRef
	|	AND AccessGroups.Profile = &DataAdministratorProfileRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.Ref = &DataAdministratorProfileRef";
	
	BeginTransaction();
	Try
		
		QueryResults = Query.ExecuteBatch();
		
		If NOT QueryResults[0].IsEmpty() Then
			AdministratorsGroup = Catalogs.AccessGroups.Administrators.GetObject();
			DataAdministratorGroup = AccessGroupDataAdministratorsRef.GetObject();
			
			If DataAdministratorGroup.Users.Count() > 0 Then
				For each Row In DataAdministratorGroup.Users Do
					If AdministratorsGroup.Users.Find(Row.User, "User") = Undefined Then
						AdministratorsGroup.Users.Add().User = Row.User;
					EndIf;
				EndDo;
				InfobaseUpdate.WriteData(AdministratorsGroup);
			EndIf;
			InfobaseUpdate.DeleteData(DataAdministratorGroup);
		EndIf;
		
		If NOT QueryResults[1].IsEmpty() Then
			DataAdministratorProfile = DataAdministratorProfileRef.GetObject();
			InfobaseUpdate.DeleteData(DataAdministratorProfile);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates the job schedule settings.
Procedure UpdateDataFillingTemplateScheduleForAccessRestriction() Export
	
	If NOT SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	Template = JobQueue.TemplateByName("DataFillingForAccessRestriction");
	TemplateObject = Template.GetObject();
	
	Schedule = New JobSchedule;
	Schedule.WeeksPeriod = 1;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.RepeatPeriodInDay = 300;
	Schedule.RepeatPause = 90;
	
	TemplateObject.Schedule = New ValueStorage(Schedule);
	TemplateObject.Write();
	
EndProcedure

// This procedure is called on processing message http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetFullControl.
//
// Parameters:
//  DataAreaUser - CatalogRef.Users - the user to be added to or removed from the Administrators 
//   group.
//  AccessAllowed - Boolean - if True, the user is added to the group,
//   If False, the user is removed from the group.
//
Procedure SetUserBelongingToAdministratorGroup(Val DataAreaUser, Val AccessAllowed) Export
	
	AdministratorsGroup = Catalogs.AccessGroups.Administrators;
	
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog.AccessGroups");
	LockItem.SetValue("Ref", AdministratorsGroup);
	Lock.Lock();
	
	GroupObject = AdministratorsGroup.GetObject();
	
	UserString = GroupObject.Users.Find(DataAreaUser, "User");
	
	If AccessAllowed AND UserString = Undefined Then
		
		UserString = GroupObject.Users.Add();
		UserString.User = DataAreaUser;
		GroupObject.Write();
		
	ElsIf NOT AccessAllowed AND UserString <> Undefined Then
		
		GroupObject.Users.Delete(UserString);
		GroupObject.Write();
	Else
		AccessManagement.UpdateUserRoles(DataAreaUser);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See JobQueueOverridable.OnReceiveTemplateList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.DataFillingForAccessRestriction.Name);
	JobTemplates.Add(Metadata.ScheduledJobs.AccessUpdateAtRecordLevel.Name);
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.0.4";
	Handler.Procedure = "AccessManagementInternalSaaS.UpdateAdministratorAccessGroupsSaaS";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.1.15";
	Handler.SharedData = True;
	Handler.Procedure = "AccessManagementInternalSaaS.UpdateDataFillingTemplateScheduleForAccessRestriction";
	
EndProcedure

// See ExportImportDataOverridable.AfterDataImport. 
Procedure AfterImportData(Container) Export
	
	Catalogs.AccessGroupProfiles.UpdateSuppliedProfiles(); 
	
EndProcedure

#EndRegion
