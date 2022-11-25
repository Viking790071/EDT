#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function GetLastPackage()
	Query = New Query;
	Query.Text = "
	|SELECT
	|	ISNULL(MAX(PackagesToSend.PackageNumber), 0) AS LastPackage1
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|";
	Result = Query.Execute();
	Selection = Result.Select();
	Selection.Next();
	
	Return Selection.LastPackage1;	
EndFunction

Procedure WriteNewPackage(RecordDate1, JSONStructure, NextPackageNumber) Export
	JSONStructure.Insert("pn", Format(NextPackageNumber, "NZ=0; NG=0"));
	JSONStructure.Insert("Configuration", String(Metadata.Name));
	JSONStructure.Insert("ConfigurationVersion", String(Metadata.Version));
	
	PackageBody = MonitoringCenterInternal.JSONStructureToString(JSONStructure);
	MD5Hash = New DataHashing(HashFunction.MD5);
	MD5Hash.Append(PackageBody + "hashSalt");
	PackageHash = MD5Hash.HashSum;
	PackageHash = StrReplace(String(PackageHash), " ", "");
	
	RecordSet = CreateRecordSet();
	NewRecord = RecordSet.Add();
	NewRecord.Period = RecordDate1;
	NewRecord.PackageNumber = NextPackageNumber;
	NewRecord.PackageBody = PackageBody;
	NewRecord.PackageHash = PackageHash;
	
	RecordSet.DataExchange.Load = True;
	RecordSet.Write(False);
EndProcedure

Procedure DeleteOldPackages() Export
	Query = New Query;
	Query.Text = "
	|SELECT
	|	COUNT(*) AS TotalPackageCount
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|";
	PackagesToSend = MonitoringCenterInternal.GetMonitoringCenterParameters("PackagesToSend");
		
	Result = Query.Execute();
	Selection = Result.Select();
	Selection.Next();
	TotalPackageCount = Selection.TotalPackageCount;
	
	If TotalPackageCount > PackagesToSend Then
		LastPackage = GetLastPackage();
		
		Query.Text = "SELECT TOP 1000
		|	PackagesToSend.PackageNumber AS PackageNumber
		|FROM
		|	InformationRegister.PackagesToSend AS PackagesToSend
		|WHERE
		|	PackagesToSend.PackageNumber < &LastPackage
		|ORDER BY
		|	PackagesToSend.PackageNumber DESC
		|";
		
		Query.Text = StrReplace(Query.Text, "1000", Format(TotalPackageCount - PackagesToSend, "NG=")); 
		
		Query.SetParameter("LastPackage", LastPackage);
		Result = Query.Execute();
		Selection = Result.Select();
		
		BeginTransaction();
		Try
			RecordSet = CreateRecordSet();
			While Selection.Next() Do
				RecordSet.Filter.PackageNumber.Set(Selection.PackageNumber);
				RecordSet.Write(True);
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Error = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(NStr("ru = 'УдалитьСтарыеПакеты';
											|en = 'DeleteOldPackages';pl = 'DeleteOldPackages';es_ES = 'DeleteOldPackages';es_CO = 'DeleteOldPackages';tr = 'DeleteOldPackages';it = 'DeleteOldPackages';de = 'DeleteOldPackages'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
			Raise Error;
		EndTry;
		
	EndIf;
EndProcedure

Procedure DeletePackage(PackageNumber) Export
	Query = New Query;
	
	Query.Text = "
	|SELECT
	|	PackagesToSend.PackageNumber AS PackageNumber
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|WHERE
	|	PackagesToSend.PackageNumber = &PackageNumber
	|";
	
	Query.SetParameter("PackageNumber", PackageNumber);
	Result = Query.Execute();
	Selection = Result.Select();
	
	BeginTransaction();
	Try
		RecordSet = CreateRecordSet();
		While Selection.Next() Do
			RecordSet.Filter.PackageNumber.Set(Selection.PackageNumber);
			RecordSet.Write(True);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(NStr("ru = 'УдалитьПакеты';
										|en = 'DeletePackages';pl = 'DeletePackages';es_ES = 'DeletePackages';es_CO = 'DeletePackages';tr = 'DeletePackages';it = 'DeletePackages';de = 'DeletePackages'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, Metadata.CommonModules.MonitoringCenterInternal,,Error);
		Raise Error;
	EndTry;
EndProcedure

Function GetPackage(PackageNumber) Export
	Query = New Query;
	
	Query.Text = "
	|SELECT
	|	PackagesToSend.PackageNumber,
	|	PackagesToSend.PackageBody,
	|	PackagesToSend.PackageHash
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|WHERE
	|	PackagesToSend.PackageNumber = &PackageNumber
	|";
		
	Query.SetParameter("PackageNumber", PackageNumber);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Package = Undefined;
	Else
		Selection = Result.Select();
		Selection.Next();
		
		Package = New Structure;
		Package.Insert("PackageNumber", Selection.PackageNumber);
		Package.Insert("PackageBody", Selection.PackageBody);
		Package.Insert("PackageHash", Selection.PackageHash);	
	EndIf;
	
	Return Package;
EndFunction

Function GetPackagesNumbers() Export
	Query = New Query;
	
	Query.Text = "
	|SELECT
	|	PackagesToSend.PackageNumber
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|ORDER BY
	|	PackagesToSend.PackageNumber
	|";
	
	Result = Query.Execute();
	PackagesNumbers = New Array;
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		While Selection.Next() Do
			PackagesNumbers.Add(Selection.PackageNumber);
		EndDo;
	EndIf;
	
	Return PackagesNumbers;
EndFunction

Procedure Clear() Export
    
    RecordSet = CreateRecordSet();
    RecordSet.Write(True);
    
EndProcedure

#EndRegion

#EndIf
