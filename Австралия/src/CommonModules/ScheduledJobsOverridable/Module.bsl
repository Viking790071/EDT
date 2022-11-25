#Region Public

// Determines the following properties of scheduled jobs:
//  - dependence on functional options.
//  - ability of execution in different application modes.
//  - other parameters.
//
// Parameters:
//  Settings - ValueTable - a table of values with the following columns: 
//    * ScheduledJob - MetadataObject:ScheduledJob - scheduled job.
//    * FunctionalOption - MetadataObject:FunctionalOption - functional option the scheduled job 
//        depends on.
//    * DependenceByT - Boolean - if the scheduled job depends on more than one functional option 
//        and you want to enable it only when all functional options are enabled, specify True for 
//        each dependency.
//        
//        The default value is False - if one or more functional options are enabled, the scheduled 
//        job is also enabled.
//    * EnableOnEnableFunctionalOption - Boolean, Undefined - if False, the scheduled job will not 
//        be enabled if the functional option is enabled. Value
//        Undefined corresponds to True.
//        The default value is Undefined.
//    * AvailableInSubordinateDIBNode - Boolean, Undefined - True or Undefined if the scheduled job 
//        is available in the DIB node.
//        The default value is Undefined.
//    * AvailableInStandaloneWorkplace - Boolean, Undefined - True or Undefined if the scheduled job 
//        is available in the standalone workplace.
//        The default value is Undefined.
//    * AvailableInSaaS - Boolean, Undefined - True or Undefined if the scheduled job is available 
//        in the SaaS.
//        The default value is Undefined.
//    * UseExternalResources - Boolean - True if the scheduled job modifies data in external sources 
//        (receiving emails, synchronizing data, etc.). Do not set the value to True for scheduled 
//        jobs that do not modify data in external sources.
//        For example, CurrencyRateImport scheduled job. Scheduled jobs operating with external 
//        resources are automatically disabled in the copy of the infobase. The default value is False.
//    * IsParameterized - Boolean - True if the scheduled job is parameterized.
//        The default value is False.
//
// Example:
//	Setting = Settings.Add();
//	Setting.ScheduledJob = Metadata.ScheduledJobs.SMSDeliveryStatusUpdate;
//	Setting.FunctionalOption = Metadata.FunctionalOptions.UseEmailClient;
//	Setting.AvailableInSaaS = False;
//
Procedure OnDefineScheduledJobSettings(Settings) Export
	
	
EndProcedure

// Allows to overwrite the default subsystem settings.
//
// Parameters:
//  Settings - Structure - a structure with keys:
//    * UnlockCommandLocation - String - determines unlock command location for operations with 
//                                                     external resources on infobase movement.
//                                                     
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure


#EndRegion