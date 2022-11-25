#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function GetRef(Description, CollectConfigurationStatistics = False) Export
	DescriptionHash = DescriptionHash(Description);
	
	Ref = FindByHash(DescriptionHash);
	If Ref = Undefined Then
		Ref = CreateNew(Description, DescriptionHash, CollectConfigurationStatistics);
	EndIf;
		
	Return Ref;
EndFunction

Function CollectConfigurationStatistics(Description) Export
	DescriptionHash = DescriptionHash(Description);
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	StatisticsAreas.CollectConfigurationStatistics
	|FROM
	|	InformationRegister.StatisticsAreas AS StatisticsAreas
	|WHERE
	|	StatisticsAreas.DescriptionHash = &DescriptionHash
	|";
	Query.SetParameter("DescriptionHash", DescriptionHash);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		CollectConfigurationStatistics = False;
	Else
		Selection = Result.Select();
		Selection.Next();
		
		CollectConfigurationStatistics = Selection.CollectConfigurationStatistics;
	EndIf;
	
	Return CollectConfigurationStatistics
EndFunction

Function DescriptionHash(Description)
	DataHashing = New DataHashing(HashFunction.SHA1);
	DataHashing.Append(Description);
	DescriptionHash = StrReplace(String(DataHashing.HashSum), " ", "");
	
	Return DescriptionHash;
EndFunction

Function FindByHash(Hash1)
	Query = New Query;
	Query.Text = "
	|SELECT
	|	StatisticsAreas.AreaID
	|FROM
	|	InformationRegister.StatisticsAreas AS StatisticsAreas
	|WHERE
	|	StatisticsAreas.DescriptionHash = &DescriptionHash
	|";
	Query.SetParameter("DescriptionHash", Hash1);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Ref = Undefined;
	Else
		Selection = Result.Select();
		Selection.Next();
		
		Ref = Selection.AreaID;
	EndIf;
	
	Return Ref;
EndFunction

Function CreateNew(Description, DescriptionHash, CollectConfigurationStatistics)
	BeginTransaction();
	
	Try
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.StatisticsAreas");
		LockItem.SetValue("DescriptionHash", DescriptionHash);
				
		Block.Lock();
		
		Ref = FindByHash(DescriptionHash);
		
		If Ref = Undefined Then
			Ref = New UUID();
			
			RecordSet = CreateRecordSet();
			RecordSet.DataExchange.Load = True;
			NewRecord1 = RecordSet.Add();
			NewRecord1.DescriptionHash = DescriptionHash;
			NewRecord1.AreaID = Ref;
			NewRecord1.Description = Description;
			NewRecord1.CollectConfigurationStatistics = CollectConfigurationStatistics;
			RecordSet.Write(False);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Ref;
EndFunction

#EndRegion

#EndIf
