# GPO Deployment tool
See https://www.cyberdrain.com/using-powershell-to-generate-and-deploy-group-policies-for-non-domain-environments/ for more information.

to solve the issues with GPO deployment for Azure AD environments, or workgroup environments I’ve created a PowerShell script that allows you to deploy group policies. I’ve also created a script to monitor if the deployment ran correctly. That way you can use your RMM to see who received the new policy and who has not.

Before we get started on the script, you will need the following two items: LGPO.exe, which we’ll use to export and deploy the policy, and winrar which will create our setup file. We download the LGPO.exe for you (Please host this somewhere you trust.). Winrar you’ll need to install yourself.

*Disclaimer/warning:* Please note that the script is destructive to the currently installed local group policies. Please run the script inside of a VM or machine that does not have any local policies. It will clear all policies by destroying the actual policy files. You have been warned 🙂