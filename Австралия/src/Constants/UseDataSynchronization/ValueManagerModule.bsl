#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If Value Then
		
		DataSeparationEnabled = Common.DataSeparationEnabled();
		Constants.UseDataSynchronizationInLocalMode.Set(Not DataSeparationEnabled);
		Constants.UseDataSynchronizationSaaS.Set(DataSeparationEnabled);
		
	Else
		
		Constants.UseDataSynchronizationInLocalMode.Set(False);
		Constants.UseDataSynchronizationSaaS.Set(False);
		
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Value
	   AND Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		ModuleDataExchangeSaaS.DataSynchronizationOnDisable(Cancel);
	EndIf;
	Job = ScheduledJobsServer.GetScheduledJob(
			Metadata.ScheduledJobs.ObsoleteSynchronizationDataDeletion);
	If Job.Use <> Value Then
		Job.Use = Value;
		Job.Write();
	EndIf;
	
EndProcedure

#EndRegion

#EndIf