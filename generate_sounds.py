import wave
import struct
import math
import random
import os

SAMPLE_RATE = 22050

def generate_wav(filename, duration_sec, generator_func):
    path = os.path.join(r"c:\Users\DEV\Desktop\PROYECTO_JUEGAZO\assets\sounds", filename)
    n_samples = int(SAMPLE_RATE * duration_sec)
    
    with wave.open(path, 'w') as wav_file:
        wav_file.setnchannels(1) # Mono
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        
        for i in range(n_samples):
            t = float(i) / SAMPLE_RATE
            sample = generator_func(t, i, n_samples)
            # Clamp to 16-bit range
            sample = max(-1, min(1, sample))
            packed_sample = struct.pack('<h', int(sample * 32767))
            wav_file.writeframesraw(packed_sample)
    print(f"Generated {filename}")

# GENERATORS

def gen_click(t, i, n):
    tone = math.sin(2 * math.pi * 1000 * t)
    env = math.exp(-t * 100)
    return tone * env

def gen_popup(t, i, n):
    tone = math.sin(2 * math.pi * (400 + 400 * t) * t)
    env = math.exp(-t * 20)
    return tone * env

def gen_step(t, i, n):
    noise = random.uniform(-1, 1)
    env = math.exp(-t * 150)
    return noise * env * 0.3

def gen_jump(t, i, n):
    # Pitch sweep up
    freq = 200 + 800 * (t ** 0.5)
    tone = math.sin(2 * math.pi * freq * t)
    env = math.exp(-t * 5)
    return tone * env

def gen_land(t, i, n):
    noise = random.uniform(-1, 1)
    env = math.exp(-t * 30)
    return noise * env * 0.5

def gen_damage(t, i, n):
    # Low buzz
    tone = 1.0 if (math.sin(2 * math.pi * 100 * t) > 0) else -1.0
    env = math.exp(-t * 15)
    return tone * env

def gen_chop(t, i, n):
    noise = random.uniform(-1, 1)
    env = math.exp(-t * 40)
    return noise * env

def gen_milk(t, i, n):
    # Squirt sound
    freq = 800 - 400 * t
    tone = math.sin(2 * math.pi * freq * t)
    noise = random.uniform(-1, 1) * 0.2
    env = math.exp(-t * 10)
    return (tone + noise) * env

def gen_harvest(t, i, n):
    # Positive glissando
    freq = 400 + 1200 * (t * t)
    tone = math.sin(2 * math.pi * freq * t)
    env = math.exp(-t * 8)
    return tone * env

def gen_cow(t, i, n):
    # Low frequency drone with some modulation
    freq = 80 + 20 * math.sin(t * 10)
    tone = math.sin(2 * math.pi * freq * t)
    env = math.sin(math.pi * t / (n/SAMPLE_RATE)) # Basic fade in/out
    return tone * env * 0.7

def gen_goat(t, i, n):
    # High frequency vibrato
    freq = 300 + 50 * math.sin(t * 30)
    tone = math.sin(2 * math.pi * freq * t)
    env = math.exp(-t * 3)
    return tone * env

def gen_chicken(t, i, n):
    # Short bursts
    burst = math.sin(t * 50) > 0.5
    tone = math.sin(2 * math.pi * 800 * t)
    return tone * (1.0 if burst else 0) * 0.5

def gen_sting(t, i, n):
    # Sharp high freq
    tone = math.sin(2 * math.pi * 2000 * t)
    env = math.exp(-t * 50)
    return tone * env

def gen_bee_loop(t, i, n):
    # Buzzing noise
    tone = math.sin(2 * math.pi * 150 * t) + 0.5 * math.sin(2 * math.pi * 300 * t)
    noise = random.uniform(-1, 1) * 0.3
    return (tone + noise) * 0.2

# Main execution
if __name__ == "__main__":
    generate_wav("ui_click.wav", 0.05, gen_click)
    generate_wav("ui_popup.wav", 0.2, gen_popup)
    generate_wav("step_grass.wav", 0.1, gen_step)
    generate_wav("jump.wav", 0.3, gen_jump)
    generate_wav("land.wav", 0.2, gen_land)
    generate_wav("damage.wav", 0.2, gen_damage)
    generate_wav("chop.wav", 0.15, gen_chop)
    generate_wav("milk.wav", 0.25, gen_milk)
    generate_wav("harvest.wav", 0.3, gen_harvest)
    generate_wav("cow_moo.wav", 1.2, gen_cow)
    generate_wav("goat_baa.wav", 0.8, gen_goat)
    generate_wav("chicken_cluck.wav", 0.4, gen_chicken)
    generate_wav("bee_sting.wav", 0.1, gen_sting)
    
    # Extensiones específicas según AudioManager.gd
    generate_wav("bees_loop.ogg", 2.0, gen_bee_loop)
    generate_wav("birds.ogg", 1.0, lambda t,i,n: random.uniform(-0.1, 0.1) * math.sin(t*5))
    generate_wav("crickets.ogg", 1.0, lambda t,i,n: random.uniform(-0.1, 0.1) * (1 if math.sin(t*100) > 0.8 else 0))
    generate_wav("wind_loop.ogg", 2.0, lambda t,i,n: random.uniform(-0.2, 0.2))
