select * from RaysPitching.Dbo.LastPitchRays

select *from RaysPitching.Dbo.RaysPitchingStats

--Question 1 AVG Pitches Per at Bat Analysis

--1a AVG Pitches Per At Bat (LastPitchRays)

SELECT AVG(1.00*pitch_number) AvgNumofPitchesPerBat FROM RaysPitching.Dbo.LastPitchRays;

--1b AVG Pitches Per At Bat Home Vs Away (LastPitchRays) -> Union

SELECT 
	 'HOME' TypeofGame,
	 AVG(1.00*pitch_number) AvgNumofPitchesPerBat 
	 FROM RaysPitching.Dbo.LastPitchRays
	 WHERE home_team='TB'
 UNION  
 SELECT 
	 'AWAY' TypeofGame, 
	 AVG(1.00*pitch_number) AvgNumofPitchesPerBat 
	 FROM RaysPitching.Dbo.LastPitchRays
	 WHERE away_team='TB'

--1c AVG Pitches Per At Bat Lefty Vs Righty  -> Case Statement 

SELECT 
	 AVG(case WHEN batter_position='L' THEN 1.00*pitch_number END) LeftyBats, 
	 AVG(CASE WHEN batter_position='R' THEN 1.00*pitch_number END) RightyBats
	 FROM RaysPitching.Dbo.LastPitchRays

--1d AVG Pitches Per At Bat Lefty Vs Righty Pitcher | Each Away Team -> Partition By

SELECT DISTINCT
	home_team,
	Pitcher_throws,
	AVG(1.00*pitch_number) OVER (partition by home_team,pitcher_throws)
	FROM RaysPitching.Dbo.LastPitchRays
	WHERE away_team='TB'

--1e Top 3 Most Common Pitch for at bat 1 through 10, and total amounts (LastPitchRays)

 WITH totalpitchsequence AS (
    SELECT DISTINCT
    pitch_name,
	pitch_number,
	count(pitch_name) OVER (partition by pitch_name,pitch_number) PitchFrequency
    FROM RaysPitching.Dbo.LastPitchRays
    WHERE pitch_number < 11
),
pitchfrequencyrankquery AS(
SELECT 
	pitch_name,
	pitch_number,
	PitchFrequency,
	RANK() OVER (partition by pitch_number order by PitchFrequency desc) pitchFrequencyRanking
	FROM totalpitchsequence
)
SELECT * 
	FROM pitchfrequencyrankquery
	WHERE pitchFrequencyRanking < 4

--1f AVG Pitches Per at Bat Per Pitcher with 20+ Innings | Order in descending (LastPitchRays + RaysPitchingStats)

SELECT 
      RPS.Name,
	  AVG(1.00*Pitch_number) AVGPitches
	  FROM RaysPitching.Dbo.LastPitchRays LPR
JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id=LPR.pitcher
	  WHERE IP >=20
	  GROUP BY RPS.Name
	  ORDER BY AVG(1.00*Pitch_number) DESC

--Question 2 Last Pitch Analysis

--2a Count of the Last Pitches Thrown in Desc Order (LastPitchRays)

SELECT 
	pitch_name,
	count(*) timesthrown
	FROM RaysPitching.Dbo.LastPitchRays
	group by pitch_name
	order by count(*) desc

--2b Count of the different last pitches Fastball or Offspeed (LastPitchRays)

SELECT 
	SUM(CASE WHEN pitch_name in ('4-Seam Fastball','Cutter') THEN 1 ELSE 0 END) Fastball,
	SUM(CASE WHEN pitch_name NOT in ('4-Seam Fastball','Cutter') THEN 1 ELSE 0 END) Offspeed
	FROM RaysPitching.Dbo.LastPitchRays

--2c Percentage of the different last pitches Fastball or Offspeed (LastPitchRays)

SELECT 
	100*SUM(CASE WHEN pitch_name in ('4-Seam Fastball','Cutter') THEN 1 ELSE 0 END)/count(*) FastballPercent,
	100*SUM(CASE WHEN pitch_name NOT in ('4-Seam Fastball','Cutter') THEN 1 ELSE 0 END)/count(*) OffspeedPercent
	FROM RaysPitching.Dbo.LastPitchRays

--2d Top 5 Most common last pitch for a Relief Pitcher vs Starting Pitcher (LastPitchRays + RaysPitchingStats)

SELECT * FROM(
	SELECT 
		pitch.POS,
		pitch.pitch_name,
		pitch.timesthrown,
		RANK() OVER(partition by pitch.POS order by pitch.timesthrown desc) PitchRank
FROM (
		SELECT RPS.POS,LPR.pitch_name,count(*) timesthrown
		FROM RaysPitching.Dbo.LastPitchRays LPR
		JOIN RaysPitching.Dbo.RaysPitchingStats RPS on RPS.pitcher_id=LPR.pitcher
		group by RPS.POS,LPR.pitch_name
     ) pitch
) b 
WHERE b.PitchRank < 6

--Question 3 Homerun analysis

--3a What pitches have given up the most HRs (LastPitchRays) 

SELECT 
	pitch_name,
	count(*) HRs
	FROM RaysPitching.Dbo.LastPitchRays
	where events='home_run'
	group by pitch_name order by count(*) desc

--3b Show HRs given up by zone and pitch, show top 5 most common

SELECT 
	TOP 5 ZONE,pitch_name, count(*) HRs
	FROM RaysPitching.Dbo.LastPitchRays
	where events='home_run'
	group by ZONE ,pitch_name
	order by count(*) desc

--3c Show HRs for each count type -> Balls/Strikes + Type of Pitcher

SELECT RPS.POS,LPR.balls,lpr.strikes,count(*) HRs
FROM RaysPitching.Dbo.LastPitchRays LPR
JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id=LPR.pitcher
where events='home_run'
group by RPS.POS,LPR.balls,lpr.strikes
order by count(*) desc

--3d Show Each Pitchers Most Common count to give up a HR (Min 30 IP)

with hrcountpitchers as (
	SELECT RPS.Name,LPR.balls,lpr.strikes,count(*) HRs
	FROM RaysPitching.Dbo.LastPitchRays LPR
	JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id=LPR.pitcher
	where events='home_run' and IP >= 30
	group by RPS.Name,LPR.balls,lpr.strikes
),
hrcountranks as(
	SELECT 
	hcp.Name,
	hcp.balls,
	hcp.strikes,
	hcp.HRs,
	rank() OVER (Partition by Name order by HRs desc) hrrank
	FROM hrcountpitchers hcp
)
SELECT ht.Name,ht.balls,ht.strikes,ht.HRs
FROM hrcountranks ht
where hrrank=1


--Question 4 Shane McClanahan
--SELECT *
--FROM RaysPitching.Dbo.LastPitchRays LPR
--JOIN RaysPitching.Dbo.RaysPitchingStats RPS ON RPS.pitcher_id=LPR.pitcher

--4a AVG Release speed, spin rate,  strikeouts, most popular zone ONLY USING LastPitchRays

SELECT 
	AVG(release_speed) AvgReleaseSpeed,
	AVG(release_spin_rate) AvgSpinRate,
	SUM(case when events='strikeout' then 1 else 0 end) strikeouts,
	MAX(zones.zone) as Zone
FROM RaysPitching.Dbo.LastPitchRays LPR
JOIN (
	SELECT Top 1 pitcher,zone,count(*) zonenum
	FROM RaysPitching.Dbo.LastPitchRays LPR
	where player_name='McClanahan, Shane'
	group by pitcher,zone
	order by count(*) desc
) zones on zones.pitcher=LPR.pitcher
where player_name='McClanahan, Shane'


--4b top pitches for each infield position where total pitches are over 5, rank them
SELECT *
FROM(
	SELECT pitch_name,count(*) timeshit,'Third' position
		FROM RaysPitching.Dbo.LastPitchRays
		where hit_location=5 and player_name='McClanahan, Shane'
		group by pitch_name
	UNION
		SELECT pitch_name,count(*) timeshit,'Short' position
			FROM RaysPitching.Dbo.LastPitchRays
			where hit_location=6 and player_name='McClanahan, Shane'
			group by pitch_name
	UNION
		SELECT pitch_name,count(*) timeshit,'Second' position
			FROM RaysPitching.Dbo.LastPitchRays
			where hit_location=4 and player_name='McClanahan, Shane'
			group by pitch_name
	UNION
		SELECT pitch_name,count(*) timeshit,'First' position
			FROM RaysPitching.Dbo.LastPitchRays
			where hit_location=3 and player_name='McClanahan, Shane'
			group by pitch_name
) a
where timeshit>4
order by timeshit desc

--4c Show different balls/strikes as well as frequency when someone is on base 

SELECT 
	balls,
	strikes,
	count(*) frequency
	FROM RaysPitching.Dbo.LastPitchRays
	WHERE (on_3b is NOT NULL or on_2b is NOT NULL or on_1b is NOT NULL)
	and player_name='McClanahan, Shane'
	group by balls,strikes
	order by count(*) desc

--4d What pitch causes the lowest launch speed

SELECT Top 1 pitch_name,AVG(launch_speed*1.00) Launch_speed
FROM RaysPitching.Dbo.LastPitchRays
where player_name='McClanahan, Shane'
group by pitch_name
order by AVG(launch_speed*1.00)